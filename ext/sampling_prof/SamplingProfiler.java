import org.jruby.*;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@JRubyClass(name = "SamplingProfiler")
public class SamplingProfiler extends RubyObject {

    private long samplingInterval; // ms
    private Thread samplingThread;
    private Map<ThreadContext, Sampling> samplings = new ConcurrentHashMap<ThreadContext, Sampling>();

    public SamplingProfiler(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    @JRubyMethod(name = "initialize", required = 1)
    public IRubyObject init(IRubyObject arg) {
        this.samplingInterval = (long) (arg.convertToFloat().getDoubleValue() * 1000);
        startSampling();
        return arg;
    }

    @JRubyMethod(name = "sampling_interval")
    public IRubyObject getSamplingInterval() {
        return JavaUtil.convertJavaToRuby(getRuntime(), (double) this.samplingInterval / 1000);
    }

    @JRubyMethod(name = "start", required = 1)
    public IRubyObject start(IRubyObject arg) {
        if (arg == null || arg.isNil()) {
            throw getRuntime().newArgumentError("Please setup output handler before start profiling");
        }

        Block handler = ((RubyProc) arg).getBlock();

        ThreadContext context = this.getRuntime().getCurrentContext();
        if (samplings.containsKey(context)) {
            return this.getRuntime().getFalse();
        }
        samplings.put(context, new Sampling(this.getRuntime(), context, handler));
        return this.getRuntime().getTrue();
    }

    @JRubyMethod
    public IRubyObject stop() {
        ThreadContext key = getRuntime().getCurrentContext();
        Sampling sampling = samplings.get(key);
        if (sampling != null && !sampling.isStop()) {
            sampling.stop();
            return this.getRuntime().getTrue();
        } else {
            return this.getRuntime().getFalse();
        }
    }

    @JRubyMethod(name = "profiling?")
    public IRubyObject isProfiling() {
        return JavaUtil.convertJavaToRuby(this.getRuntime(), running() && samplings.containsKey(getRuntime().getCurrentContext()));
    }

    // this method is not thread-safe, should only be called once to terminate profiling
    @JRubyMethod
    public IRubyObject terminate() {
        if (running()) {
            samplingThread.interrupt();
            return waitSamplingStop();
        } else {
            return this.getRuntime().getFalse();
        }
    }

    private synchronized boolean running() {
        return samplingThread != null;
    }

    private synchronized void startSampling() {
        if (running()) {
            return;
        }
        samplingThread = new Thread(new Runnable() {
            @Override
            public void run() {
                while (true){
                    for(Sampling sampling : samplings.values()) {
                        if (sampling.isStop()) {
                            samplings.remove(sampling.getContext());
                            sampling.output();
                        } else {
                            sampling.process();
                        }
                    }
                    try {
                        Thread.sleep(samplingInterval);
                    } catch (InterruptedException e) {
                        break;
                    }
                }
                for(Sampling sampling : samplings.values()) {
                    sampling.output();
                }
            }
        });
        samplingThread.start();
    }

    private synchronized IRubyObject waitSamplingStop() {
        if (samplingThread == null) {
            return this.getRuntime().getFalse();
        }
        try {
            this.samplingThread.join();
            this.samplingThread = null;
            return this.getRuntime().getTrue();
        } catch (InterruptedException e) {
            // ignore...
            return this.getRuntime().getFalse();
        }
    }
}
