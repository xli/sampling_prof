require 'sampling_prof.jar'

class SamplingProf
  DEFAULT_OUTPUT_FILE = 'profile.txt'

  def profile(path=nil, &block)
    start(path)
    yield if block_given?
  ensure
    stop if block_given?
  end

  def start(path=nil)
    __start__(&output(path))
  end

  def output(path=nil)
    path ||= DEFAULT_OUTPUT_FILE
    lambda do |data|
      nodes, counts, call_graph = data
      # puts "[DEBUG]data => #{data.inspect}"
      File.open(path, 'w') do |f|
        nodes.each do |node|
          # node name, node id
          f.puts node.join(',')
        end
        f.puts ""
        counts.each do |count|
          # node id, count
          f.puts count.join(",")
        end
        f.puts ""
        call_graph.each do |v|
          # from node id, to node id, count
          f.puts v.flatten.join(",")
        end
      end
    end
  end

  def report(type, file=DEFAULT_OUTPUT_FILE)
    file ||= DEFAULT_OUTPUT_FILE
    nodes, counts, call_graph = File.read(file).split("\n\n")
    nodes = nodes.split("\n").inject({}) do |ret, l|
      n, i = l.split(',')
      ret[i.to_i] = n
      ret
    end
    counts = counts.split("\n").map do |l|
      l.split(',').map(&:to_i)
    end
    total_count, report = flat_report(nodes, counts)
    puts "total counts: #{total_count}"
    puts "calls\t%\tname"
    report.first(20).each do |v|
      puts v.join("\t")
    end
  end

  def flat_report(nodes, counts)
    total = counts.map{|_,c| c}.reduce(:+)
    reports = counts.sort_by{|_,c| -c}.map do |id, c|
      [c, '%.2f%' % (100 * c.to_f/total), nodes[id]]
    end
    [total, reports]
  end
end
