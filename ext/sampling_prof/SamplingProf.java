import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@JRubyClass(name = "SamplingProf")
public class SamplingProf extends RubyObject {

    private long samplePeriod; // ms
    private Thread samplingThread;
    private boolean multithreading = false;
    private int multithreadingFlushCount;

    private Set<ThreadContext> samplingContexts;
    private Block defaultCallback;

    public SamplingProf(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    @JRubyMethod(name = "initialize", required = 1, optional = 2)
    public IRubyObject initialize(IRubyObject[] args, Block block) {
        this.samplePeriod = (long) (args[0].convertToFloat().getDoubleValue() * 1000);
        this.samplingContexts = Collections.newSetFromMap(new ConcurrentHashMap<ThreadContext, Boolean>());
        this.defaultCallback = block.isGiven() ? block : null;
        if (args.length >= 2) {
            this.multithreading = args[1].isTrue();
            if (args.length == 3) {
                this.multithreadingFlushCount = args[2].convertToInteger().getBigIntegerValue().intValue();
            } else {
                this.multithreadingFlushCount = (int) (2 * 60 * 1000 / this.samplePeriod);
            }
        }
        return super.getRuntime().getNil();
    }

    @JRubyMethod(name = "__start__")
    public IRubyObject start(Block callback) {
        if (this.multithreading || !running()) {
            samplingContexts.add(this.getRuntime().getCurrentContext());
            startSampling(this.defaultCallback != null ? defaultCallback : callback);
            return this.getRuntime().getTrue();
        } else {
            return this.getRuntime().getFalse();
        }
    }

    @JRubyMethod
    public IRubyObject stop() {
        if (!this.multithreading) {
            return terminate();
        } else {
            return JavaUtil.convertJavaToRuby(this.getRuntime(), samplingContexts.remove(getRuntime().getCurrentContext()));
        }
    }

    @JRubyMethod(name = "profiling?")
    public IRubyObject isProfiling() {
        return JavaUtil.convertJavaToRuby(this.getRuntime(), running());
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

    private synchronized void startSampling(final Block callback) {
        if (running()) {
            return;
        }
        final Ruby ruby = this.getRuntime();
        samplingThread = new Thread(new Runnable() {
            @Override
            public void run() {
                boolean endless = multithreading;
                do {
                    Sampling sampling = new Sampling(ruby, samplingContexts);
                    int flushCount = multithreadingFlushCount;
                    while (!multithreading || (multithreading && flushCount-- > 0)) {
                        sampling.process();
                        try {
                            Thread.sleep(samplePeriod);
                        } catch (InterruptedException e) {
                            endless = false;
                            break;
                        }
                    }
                    callback.call(ruby.getCurrentContext(), sampling.result());
                } while(endless);
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
