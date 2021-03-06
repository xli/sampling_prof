import org.jruby.Ruby;
import org.jruby.RubyThread;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import org.jruby.runtime.backtrace.BacktraceData;
import org.jruby.runtime.backtrace.RubyStackTraceElement;
import org.jruby.runtime.backtrace.TraceType;

import java.util.*;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Created by Xiao Li on 3/21/14.
 */
public class Sampling {

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

            return fromId == path.fromId && toId == path.toId;

        }

        @Override
        public int hashCode() {
            int result = fromId;
            result = 31 * result + toId;
            return result;
        }
    }

    public static class Count {
        private int self;
        private int total;

        public Count(int self, int total) {
            this.self = self;
            this.total = total;
        }
    }

    private static final String NODE_DATA_SPLITTER = ":";

    private final Ruby ruby;
    private final ThreadContext context;
    private final RubyThread thread;
    private final Block outputHandler;
    private final Map<String, Integer> nodes = new HashMap<String, Integer>();
    private final Map<Path, Integer> callGraph = new HashMap<Path, Integer>();
    private final Map<Integer, Count> counts = new HashMap<Integer, Count>();
    private final long startAt;
    private final AtomicLong endAt = new AtomicLong(-1);

    public Sampling(Ruby ruby, ThreadContext context, Block outputHandler) {
        this.ruby = ruby;
        this.context = context;
        this.outputHandler = outputHandler;
        this.startAt = System.currentTimeMillis();
        this.thread = context.getThread();
    }

    public ThreadContext getContext() {
        return this.context;
    }

    // the following methods called by multiple threads
    public boolean isStop() {
        return this.endAt.get() > 0;
    }

    // the following methods called by thread of starting&stopping profiling
    public void stop() {
        this.endAt.set(System.currentTimeMillis());
    }

    // the following methods called by sampling thread.
    // these methods should be called in single thread, so that we don't need to
    // sync hash maps we used to store data.
    public void output() {
        if (nodes.isEmpty() || ruby.getCurrentContext().getThread() == null) {
            return;
        }
        outputHandler.call(ruby.getCurrentContext(), result());
    }

    public boolean process() {
        if (!thread.isAlive()) {
            return false;
        }
        Thread nt = thread.getNativeThread();
        if (nt == null) {
            return false;
        }
        StackTraceElement[] stackTrace = nt.getStackTrace();
        if (stackTrace.length == 0) {
            return false;
        }
        BacktraceData data = TraceType.Gather.CALLER.getBacktraceData(context, stackTrace, false);
        if(isStop()) {
            return false;
        }
        RubyStackTraceElement[] backtrace = data.getBacktrace(ruby);

        int parentId = -1;
        Set<Path> paths = new HashSet<Path>();
        Set<Integer> calls = new HashSet<Integer>();
        for (int i = backtrace.length - 1; i >= 0; i--) {
            int nodeId = nodeId(node(backtrace[i]));
            // count self calls, this is the code where CPU time is spending
            if (i == 0) {
                if (counts.containsKey(nodeId)) {
                    counts.get(nodeId).self++;
                } else {
                    counts.put(nodeId, new Count(1, 0));
                }
            }

            // We need ignore duplicated paths generated by recursive calls.
            // One method call (from A to B) should only count once for one sample.
            // Hence, P(A=method) = 1 when a method showed up in all result.
            Path path = new Path(parentId, nodeId);
            if (!paths.contains(path)) {
                paths.add(path);
                if (callGraph.containsKey(path)) {
                    callGraph.put(path, callGraph.get(path) + 1);
                } else {
                    callGraph.put(path, 1);
                }

            }
            if (!calls.contains(nodeId)) {
                calls.add(nodeId);
                if (counts.containsKey(nodeId)) {
                    counts.get(nodeId).total++;
                } else {
                    counts.put(nodeId, new Count(0, 1));
                }
            }
            parentId = nodeId;
        }
        return true;
    }

    private IRubyObject result() {
        StringBuilder buffer = new StringBuilder();
        buffer.append(endAt.get() - startAt).append("\n");
        buffer.append("\n");
        for (Map.Entry<String, Integer> entry1 : nodes.entrySet()) {
            buffer.append(entry1.getKey()).append(",").append(entry1.getValue());
            buffer.append("\n");
        }
        buffer.append("\n");
        for (Map.Entry<Integer, Count> entry1 : counts.entrySet()) {
            Count count = entry1.getValue();
            buffer.append(entry1.getKey()).append(",").append(count.self).append(",").append(count.total);
            buffer.append("\n");
        }
        buffer.append("\n");
        for (Map.Entry<Path, Integer> entry : callGraph.entrySet()) {
            Path key = entry.getKey();
            buffer.append(key.fromId).append(",").append(key.toId).append(",").append(entry.getValue());
            buffer.append("\n");
        }

        return JavaUtil.convertJavaToRuby(ruby, buffer.toString());
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

    private String node(RubyStackTraceElement backtrace) {
        return backtrace.getFileName() + NODE_DATA_SPLITTER + backtrace.getLineNumber() + NODE_DATA_SPLITTER + backtrace.getMethodName();

    }
}
