import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.backtrace.BacktraceData;
import org.jruby.runtime.backtrace.RubyStackTraceElement;
import org.jruby.runtime.backtrace.TraceType;
import org.jruby.runtime.builtin.IRubyObject;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

@JRubyClass(name = "SamplingProf")
public class SamplingProf extends RubyObject {

    public static RubyStackTraceElement[] getRubyStackTrace(ThreadContext context) {
        StackTraceElement[] stackTrace = context.getThread().getNativeThread().getStackTrace();

        BacktraceData data = TraceType.Gather.CALLER.getBacktraceData(context, stackTrace, false);
        return data.getBacktrace(context.getRuntime());
    }

    public static class Path {

        private final int fromId;
        private final int toId;

        public Path(int fromId, int toId) {
            this.fromId = fromId;
            this.toId = toId;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (o == null || getClass() != o.getClass()) return false;

            Path path = (Path) o;

            if (fromId != path.fromId) return false;
            if (toId != path.toId) return false;

            return true;
        }

        @Override
        public int hashCode() {
            int result = fromId;
            result = 31 * result + toId;
            return result;
        }

        public IRubyObject[] toRuby(Ruby ruby) {
            return new IRubyObject[]{
                    JavaUtil.convertJavaToRuby(ruby, fromId),
                    JavaUtil.convertJavaToRuby(ruby, toId)
            };
        }
    }

    private static class Sampling {
        private Map<String, Integer> nodes = new HashMap<String, Integer>();
        private Map<Path, Integer> callGraph = new HashMap<Path, Integer>();
        private Map<Integer, Integer> counts = new HashMap<Integer, Integer>();
        private Ruby ruby;
        private ThreadContext context;

        public Sampling(ThreadContext context) {
            this.context = context;
            this.ruby = context.getRuntime();
        }

        private IRubyObject samples() {
            return RubyArray.newArray(ruby, new IRubyObject[]{
                    nodesToRuby(),
                    countsToRuby(),
                    callGraphToRuby()
            });
        }

        public void takeSample() {
            RubyStackTraceElement[] backtrace = getRubyStackTrace(context);
            takeCountSample(backtrace[0]);
            takeCallPaths(backtrace);
        }

        private void takeCallPaths(RubyStackTraceElement[] backtrace) {
            int parentId = -1;
            for (int i = backtrace.length - 1; i >= 0; i--) {
                int nodeId = nodeId(node(backtrace[i]));
                Path path = new Path(parentId, nodeId);
                if (callGraph.containsKey(path)) {
                    callGraph.put(path, callGraph.get(path) + 1);
                } else {
                    callGraph.put(path, 1);
                }
                parentId = nodeId;
            }
        }

        private void takeCountSample(RubyStackTraceElement traceElement) {
            int nodeId = nodeId(node(traceElement));
            if (counts.containsKey(nodeId)) {
                counts.put(nodeId, counts.get(nodeId) + 1);
            } else {
                counts.put(nodeId, 1);
            }
        }

        private int nodeId(String node) {
            if (nodes.containsKey(node)) {
                return nodes.get(node);
            } else {
                int id = nodes.size();
                nodes.put(node, id);
                return id;
            }
        }

        private static final String NODE_DATA_SPLITTER = ":";
        private String node(RubyStackTraceElement backtrace) {
            StringBuffer buffer = new StringBuffer();
            buffer.append(backtrace.getFileName()).append(NODE_DATA_SPLITTER).
                    append(backtrace.getLineNumber()).append(NODE_DATA_SPLITTER).
                    append(backtrace.getMethodName());
            return buffer.toString();

        }

        private RubyArray callGraphToRuby() {
            RubyArray array = RubyArray.newArray(ruby, callGraph.size());
            for (Map.Entry<Path, Integer> entry : callGraph.entrySet()) {
                RubyArray count = RubyArray.newArray(ruby, new IRubyObject[]{
                        RubyArray.newArray(ruby, entry.getKey().toRuby(ruby)),
                        JavaUtil.convertJavaToRuby(ruby, entry.getValue())
                });
                array.append(count);
            }
            return array;
        }

        private RubyArray nodesToRuby() {
            RubyArray array = RubyArray.newArray(ruby, nodes.size());
            for (Map.Entry<String, Integer> entry : nodes.entrySet()) {
                RubyArray count = RubyArray.newArray(ruby, new IRubyObject[]{
                        JavaUtil.convertJavaToRuby(ruby, entry.getKey()),
                        JavaUtil.convertJavaToRuby(ruby, entry.getValue())
                });
                array.append(count);
            }
            return array;
        }

        private RubyArray countsToRuby() {
            RubyArray array = RubyArray.newArray(ruby, counts.size());
            for (Map.Entry<Integer, Integer> entry : counts.entrySet()) {
                RubyArray count = RubyArray.newArray(ruby, new IRubyObject[]{
                        JavaUtil.convertJavaToRuby(ruby, entry.getKey()),
                        JavaUtil.convertJavaToRuby(ruby, entry.getValue())
                });
                array.append(count);
            }
            return array;
        }

        private void log(Object obj) {
            System.out.println(obj);
        }

    }

    private AtomicBoolean running = new AtomicBoolean(false);
    private long samplePeriod; // ms
    private Thread samplingThread;


    public SamplingProf(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    @JRubyMethod(name = "initialize", required = 1)
    public IRubyObject initialize(IRubyObject samplePeriod) {
        this.samplePeriod = (long) (samplePeriod.convertToFloat().getDoubleValue() * 1000);
        return samplePeriod;
    }

    @JRubyMethod(name = "__start__")
    public IRubyObject start(Block callback) {
        if (running.compareAndSet(false, true)) {
            startSampling(callback);
            return this.getRuntime().getTrue();
        } else {
            return this.getRuntime().getFalse();
        }
    }

    @JRubyMethod
    public IRubyObject stop() {
        if (running.compareAndSet(true, false)) {
            waitSamplingStop();
            return this.getRuntime().getTrue();
        } else {
            return this.getRuntime().getFalse();
        }
    }

    @JRubyMethod(name = "profiling?")
    public synchronized IRubyObject isProfiling() {
        return JavaUtil.convertJavaToRuby(this.getRuntime(), samplingThread != null);
    }

    private synchronized void startSampling(final Block callback) {
        final Ruby ruby = this.getRuntime();
        final ThreadContext context = ruby.getCurrentContext();

        samplingThread = new Thread(new Runnable() {
            @Override
            public void run() {
                final Sampling sampling = new Sampling(context);
                while (running.get()) {
                    sampling.takeSample();
                    sleep();
                }
                callback.call(ruby.getCurrentContext(), sampling.samples());
            }
        });
        samplingThread.start();
    }

    private synchronized void waitSamplingStop() {
        try {
            this.samplingThread.join();
            this.samplingThread = null;
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
    }

    private void sleep() {
        try {
            Thread.sleep(samplePeriod);
        } catch (InterruptedException e) {
            throw this.getRuntime().newRaiseException(this.getRuntime().getInterrupt(), e.getMessage());
        }
    }

}
