require 'set'
class SamplingProf
  class Sampling
    def initialize(threads)
      @samples = Hash.new{|h,k| h[k] = [0, 0] }
      @call_graph = Hash.new{|h,k| h[k] = 0}
      @nodes = {}
      @threads = threads
    end

    def result
      ret = []
      ret << @nodes.map {|node| node.join(',')}.join("\n")
      ret << @samples.map {|count| count.flatten.join(',')}.join("\n")
      ret << @call_graph.map {|v| v.flatten.join(',')}.join("\n")
      "#{ret.join("\n\n")}\n"
    end

    def process
      @threads.each do |thread|
        locations = thread.backtrace_locations
        from = -1
        paths = []
        calls = []
        top_index = locations.size - 1
        locations.reverse.each_with_index do |loc, i|
          node_id = node_id(loc)
          if i == top_index
            @samples[node_id][0] += 1
          end

          path = [from, node_id]
          if !paths.include?(path)
            paths << path
            @call_graph[path] += 1
          end
          if !calls.include?(node_id)
            calls << node_id
            @samples[node_id][1] += 1
          end
          from = node_id
        end
      end
    end

    def node_id(loc)
      @nodes[call_element(loc)] ||= @nodes.size
    end

    def call_element(loc)
      [loc.path, loc.lineno, loc.label].join(":")
    end
  end

  class Threads
    def initialize
      @set = Set.new
      @mutex = Mutex.new
    end

    def each(&block)
      dup.each(&block)
    end

    def dup
      @mutex.synchronize { @set.dup }
    end

    def add(obj)
      @mutex.synchronize { @set.add(obj) }
    end

    def delete(obj)
      @mutex.synchronize { @set.delete(obj) }
    end
  end

  def initialize(period, multithreading=false, multithreading_flush_count=2*60/period, &block)
    @period = period
    @multithreading = multithreading
    @multithreading_flush_count = multithreading_flush_count
    @output_handler = block_given? ? block : nil
    @sampling_thread = nil
    @threads = Threads.new
    @running = false
  end

  def __start__(&block)
    if @multithreading || !@running
      @running = true
      @threads.add(Thread.current)
      callback = @output_handler ? @output_handler : block
      @sampling_thread ||= Thread.start do
        loop do
          sampling = Sampling.new(@threads)
          flush_count = @multithreading_flush_count
          loop do
            break unless @running
            if @multithreading
              flush_count-=1
              break if flush_count <= 0
            end
            sampling.process
            sleep @period
          end
          callback.call(sampling.result)
          break unless @running
        end
      end
      true
    end
  end

  def stop
    if @running
      if @multithreading
        @threads.delete(Thread.current)
      else
        terminate
      end
      true
    end
  end

  def terminate
    @running = false
    @sampling_thread.join
    @sampling_thread = nil
    true
  end

  def profiling?
    !!@sampling_thread
  end
end
