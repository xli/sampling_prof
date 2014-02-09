require 'sampling_prof.jar'

class SamplingProf
  DEFAULT_OUTPUT_FILE = 'profile.txt'

  attr_accessor :output_file

  def output_file
    @output_file ||= DEFAULT_OUTPUT_FILE
  end

  def profile(&block)
    start
    yield if block_given?
  ensure
    stop if block_given?
  end

  def start
    __start__(&output)
  end

  def output
    lambda do |data|
      nodes, counts, call_graph = data
      File.open(output_file, 'w') do |f|
        nodes.each do |node|
          # node name, node id
          f.puts node.join(',')
        end
        f.puts ""
        counts.each do |count|
          # node id, count
          f.puts count.flatten.join(",")
        end
        f.puts ""
        call_graph.each do |v|
          # from node id, to node id, count
          f.puts v.flatten.join(",")
        end
      end
    end
  end

  def report(type, output=$stdout)
    nodes, counts, call_graph = File.read(output_file).split("\n\n")
    nodes = nodes.split("\n").inject({}) do |ret, l|
      n, i = l.split(',')
      ret[i.to_i] = n
      ret
    end

    counts = counts.split("\n").map do |l|
      l.split(',').map(&:to_i)
    end
    total_samples, report = flat_report(nodes, counts)

    output.puts "total samples: #{total_samples}"
    output.puts "self\t%\ttotal\t%\tname"
    report.first(20).each do |v|
      output.puts v.join("\t")
    end
  end

  def flat_report(nodes, counts)
    total = counts.map{|_,sc,tc| sc}.reduce(:+)
    reports = counts.reject{|_,sc,tc| sc == 0}.sort_by{|_,sc,tc| -sc}.map do |id, sc, tc|
      [sc, '%.2f%' % (100 * sc.to_f/total),
       tc, '%.2f%' % (100 * tc.to_f/total),
       nodes[id]]
    end
    [total, reports]
  end

end
