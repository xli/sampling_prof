import org.jruby.*;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

@JRubyClass(name = "SamplingProf")
public class SamplingProf extends RubyObject {

    private long samplingInterval; // ms
    private Thread samplingThread;
    private boolean multithreading = false;

    private SamplingContexts threads = new SamplingContexts();
    private Block outputHandler;
    private Long outputInterval; // ms

    public SamplingProf(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    @JRubyMethod(name = "max_sampling_threads=", required = 1)
    public IRubyObject setMaxSamplingThreads(IRubyObject arg) {
        threads.setMax(arg.convertToInteger().getBigIntegerValue().intValue());
        return arg;
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

    @JRubyMethod(name = "multithreading=", required = 1)
    public IRubyObject setMultithreading(IRubyObject arg) {
        this.multithreading = arg.isTrue();
        return arg;
    }

    @JRubyMethod(name = "output_interval=", required = 1)
    public IRubyObject setOutputInterval(IRubyObject arg) {
        if (arg.isNil()) {
            this.outputInterval = null;
        } else {
            this.outputInterval = (long) (arg.convertToFloat().getDoubleValue() * 1000);
        }
        return arg;
    }

    @JRubyMethod(name = "sampling_interval")
    public IRubyObject getSamplingInterval() {
        return JavaUtil.convertJavaToRuby(getRuntime(), (double) this.samplingInterval / 1000);
    }

    @JRubyMethod(name = "multithreading")
    public IRubyObject getMultithreading() {
        return JavaUtil.convertJavaToRuby(getRuntime(), this.multithreading);
    }

    @JRubyMethod(name = "output_interval")
    public IRubyObject getOutputInterval() {
        if (this.outputInterval == null) {
            return getRuntime().getNil();
        }
        return JavaUtil.convertJavaToRuby(getRuntime(), (double) this.outputInterval / 1000);
    }

    @JRubyMethod
    public IRubyObject start() {
        if (this.multithreading || !running()) {
            threads.add(this.getRuntime().getCurrentContext());
            startSampling();
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
            ThreadContext key = getRuntime().getCurrentContext();
            if (threads.remove(key)) {
                return this.getRuntime().getTrue();
            } else {
                return this.getRuntime().getFalse();
            }
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
                boolean endless = multithreading;
                do {
                    Sampling sampling = new Sampling(ruby, threads);
                    while (outputInterval == null || outputInterval > sampling.runtime()) {
                        sampling.process();
                        try {
                            Thread.sleep(samplingInterval);
                        } catch (InterruptedException e) {
                            endless = false;
                            break;
                        }
                    }
                    if (sampling.hasSamplingData()) {
                        outputHandler.call(ruby.getCurrentContext(), sampling.result());
                    }
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
