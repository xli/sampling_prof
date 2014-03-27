require 'set'
require 'thread'

class SamplingProf
  class Sampling
    def initialize(threads)
      @samples = Hash.new{|h,k| h[k] = [0, 0] }
      @call_graph = Hash.new{|h,k| h[k] = 0}
      @nodes = {}
      @threads = threads
      @start_at = Time.now
    end

    def runtime
      Time.now - @start_at
    end

    def sampling_data?
      !@nodes.empty?
    end

    def result
      ret = [@threads.sampling_runtime * 1000]
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
      @hash = {}
      @mutex = Mutex.new
      @remain_sampling_time = 0
    end

    def each(&block)
      dup.each(&block)
    end

    def dup
      @mutex.synchronize { @hash.keys.dup }
    end

    def add(obj)
      @mutex.synchronize { @hash[obj] = Time.now }
    end

    def sampling_runtime
      now = Time.now
      @mutex.synchronize do
        ret, @remain_sampling_time = @remain_sampling_time, 0
        @hash.keys.each do |k|
          ret += now - @hash[k]
          @hash[k] = now
        end
        ret
      end
    end

    def delete(obj)
      @mutex.synchronize do
        start = @hash.delete(obj)
        @remain_sampling_time += Time.now - start
      end
    end
  end

  attr_accessor :sampling_interval, :multithreading, :output_interval, :output_handler

  def internal_initialize
    @running = false
    @sampling_thread = nil
    @threads = Threads.new
  end

  def start
    if @multithreading || !@running
      @running = true
      @threads.add(Thread.current)
      @sampling_thread ||= Thread.start do
        loop do
          sampling = Sampling.new(@threads)
          loop do
            break unless @running
            if @multithreading
              break if output_interval < sampling.runtime
            end
            sampling.process
            sleep @sampling_interval
          end
          if sampling.sampling_data?
            @output_handler.call(sampling.result)
          end
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
