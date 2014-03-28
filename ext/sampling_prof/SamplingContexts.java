import org.jruby.runtime.ThreadContext;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Created by xli on 3/27/14.
 */
public class SamplingContexts {
    private ConcurrentMap<ThreadContext, AtomicLong> contexts = new ConcurrentHashMap<ThreadContext, AtomicLong>();
    private AtomicLong remainSamplingTime = new AtomicLong();
    private int max = 4;

    public void setMax(int max) {
        this.max = max;
    }

    public boolean remove(ThreadContext context) {
        if (contexts.containsKey(context)) {
            AtomicLong start = contexts.remove(context);
            remainSamplingTime.addAndGet(System.currentTimeMillis() - start.get());
            return true;
        } else {
            return false;
        }
    }

    public void add(ThreadContext context) {
        contexts.put(context, new AtomicLong(System.currentTimeMillis()));
    }

    public long runtime() {
        long now = System.currentTimeMillis();
        long ret = remainSamplingTime.getAndSet(0);
        for(AtomicLong start : contexts.values()) {
            ret += now - start.getAndSet(now);
        }
        return ret;
    }

    public List<ThreadContext> sampleContexts() {
        List<ThreadContext> list = Arrays.asList(contexts.keySet().toArray(new ThreadContext[0]));
        if (list.size() > this.max) {
            Collections.shuffle(list);
            return list.subList(0, this.max);
        } else {
            return list;
        }
    }
}
