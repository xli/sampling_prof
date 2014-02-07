import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.BasicLibraryService;

import java.io.IOException;

public class SamplingProfService implements BasicLibraryService {
    public boolean basicLoad(final Ruby ruby) throws IOException {
        RubyClass samplingProf = ruby.defineClass("SamplingProf", ruby.getObject(), new ObjectAllocator() {
            public IRubyObject allocate(Ruby ruby, RubyClass klazz) {
                return new SamplingProf(ruby, klazz);
            }
        });
        samplingProf.defineAnnotatedMethods(SamplingProf.class);
        return true;
    }
}
