$LOAD_PATH << File.dirname(__FILE__) + '/../lib'
require 'test/unit'
require 'sampling_prof'

def fib(i)
  if i == 1
    0
  elsif i == 2
    1
  else
    fib(i - 1) + fib(i - 2)
  end
end
