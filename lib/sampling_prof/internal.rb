
class SamplingProf
  class Sample < Struct.new(:self, :total)
  end

  class Sampling
    def initialize
      @samples = Hash.new{|h,k| h[k] = [0, 0] }
      @call_graph = Hash.new{|h,k| h[k] = 0}
      @nodes = {}
    end

    def result
      [@nodes.to_a, @samples.to_a, @call_graph.to_a]
    end

    def process(locations)
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

    def node_id(loc)
      @nodes[call_element(loc)] ||= @nodes.size
    end

    def call_element(loc)
      [loc.path, loc.lineno, loc.label].join(":")
    end
  end

  def initialize(period)
    @period = period
    @running = false
    @sampling_thread = nil
  end

  def __start__(&block)
    unless @running
      @running = true
      target = Thread.current
      @sampling_thread = Thread.start do
        sampling = Sampling.new
        loop do
          break unless @running
          sampling.process(target.backtrace_locations)
          sleep @period
        end
        block.call(sampling.result)
      end
      true
    end
  end

  def stop
    if @running
      @running = false
      @sampling_thread.join
      @sampling_thread = nil
      true
    end
  end

  def profiling?
    !!@sampling_thread
  end
end
