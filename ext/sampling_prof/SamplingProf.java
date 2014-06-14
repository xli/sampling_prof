import org.jruby.*;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@JRubyClass(name = "SamplingProf")
public class SamplingProf extends RubyObject {

    private long samplingInterval; // ms
    private Thread samplingThread;

    private Block outputHandler;
    private Map<ThreadContext, Sampling> samplings = new ConcurrentHashMap<ThreadContext, Sampling>();

    public SamplingProf(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    @JRubyMethod(name = "internal_initialize")
    public IRubyObject internalInitialize() {
        startSampling();
        return getRuntime().getNil();
    }

    @JRubyMethod(name = "sampling_interval=", required = 1)
    public IRubyObject setSamplingInterval(IRubyObject arg) {
        this.samplingInterval = (long) (arg.convertToFloat().getDoubleValue() * 1000);
        return arg;
    }

    @JRubyMethod(name = "output_handler=", required = 1)
    public IRubyObject setOutputHandler(IRubyObject arg) {
        this.outputHandler = ((RubyProc) arg).getBlock();
        return arg;
    }

    @JRubyMethod(name = "sampling_interval")
    public IRubyObject getSamplingInterval() {
        return JavaUtil.convertJavaToRuby(getRuntime(), (double) this.samplingInterval / 1000);
    }

    @JRubyMethod
    public IRubyObject start() {
        ThreadContext context = this.getRuntime().getCurrentContext();
        if (samplings.containsKey(context)) {
            return this.getRuntime().getFalse();
        }
        samplings.put(context, new Sampling(this.getRuntime()));
        return this.getRuntime().getTrue();
    }

    @JRubyMethod
    public IRubyObject stop() {
        ThreadContext key = getRuntime().getCurrentContext();
        Sampling sampling = samplings.remove(key);
        if (sampling != null) {
            output(key, sampling);
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
        if (outputHandler == null) {
            throw getRuntime().newArgumentError("Please setup output handler before start profiling");
        }
        final Ruby ruby = this.getRuntime();
        samplingThread = new Thread(new Runnable() {
            @Override
            public void run() {
                while (true){
                    for(Map.Entry<ThreadContext, Sampling> entry : samplings.entrySet()) {
                        entry.getValue().process(entry.getKey());
                    }
                    try {
                        Thread.sleep(samplingInterval);
                    } catch (InterruptedException e) {
                        break;
                    }
                }

                for(Map.Entry<ThreadContext, Sampling> entry : samplings.entrySet()) {
                    output(entry.getKey(), entry.getValue());
                }
            }
        });
        samplingThread.start();
    }

    private void output(ThreadContext context, Sampling sampling) {
        if (sampling.hasSamplingData()) {
            outputHandler.call(context, sampling.result());
        }
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
