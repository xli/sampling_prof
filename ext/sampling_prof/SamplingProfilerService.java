import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.BasicLibraryService;

import java.io.IOException;

public class SamplingProfilerService implements BasicLibraryService {
    public boolean basicLoad(final Ruby ruby) throws IOException {
        RubyClass samplingProf = ruby.defineClass("SamplingProfiler", ruby.getObject(), new ObjectAllocator() {
            public IRubyObject allocate(Ruby ruby, RubyClass klazz) {
                return new SamplingProfiler(ruby, klazz);
            }
        });
        samplingProf.defineAnnotatedMethods(SamplingProfiler.class);
        return true;
    }
}
