SamplingProf
===============

SamplingProf is a profiling tool that operates by sampling your running thread stacktrace. The result is statistical approximation, but it allows your code to run near full speed.

Quick start
---------------

For single thread profiling, start with default options:

  prof = SamplingProf.new
  prof.profile do
  ... your code ...
  end

After profiling finished, the output will be write to file SamplingProf::DEFAULT_OUTPUT_FILE

Options
---------------

SamplingProf class initializer takes 3 arguments:

1. sampling interval: seconds
2. multithreading: boolean
3. output interval: seconds

SamplingProf class also takes block as another option to overwite default output handler, the default output handler will write output data to a local file defined by output_file attribute, which is default to SamplingProf::DEFAULT_OUTPUT_FILE

### Sampling interval

This is an interval to control how frequent SamplingProf should take sample of target thread stacktrace.
The default value is 0.1 seconds.

### Multithreading mode

When running SamplingProf in multithreading environment (e.g. Rails multithreading production environment), you need turn on multithreading mode so that you can profile all requests processing at same time cross threads.

### output interval

Output interval controls how frequent SamplingProf should call output handler to flush out cached data.
The default value of output interval is depend on the option of multithreading.
When multithreading is off, the default value is nil, because single thread mode is more likely only need to do once data output when the profiling finished.

When multithreading is on, the default value is 60 seconds, means every 60 seconds SamplingProf will call output handler once to flush out data and restart to cumulate data.

Output data format
---------------

Output data is divided into a number of chunks. Chunks are separated by 2 "\n" chars.

List of chunks in order:

1. runtime
2. call element id map
3. counts
4. call graph

### runtime chunk

A number represents time of collecting data.
It should be only one line.
The time unit is ms.
Runtime can be used to compute an estimated runtime of a call element.

When it's multithreading mode, the runtime result is a little bit tricky.
But think about we queuing up all threads, and put them into single thread, the time doing sampling in this one single thread is the runtime we output here.

### call element id map

For storage efficiency, we build this map for counts and call graph chunks to use id instead of a call element string.
One line one call element string and its id, separated by a comma.

#### call element format

A call element represents a line of code while program running. It has 3 components:

1. file path
2. line number
3. method name

A call element string is a join of 3 components with char ":", for example: ./lib/sampling_prof.rb:5:initialize

### counts

SamplingProf collects count of each call element at runtime. There are 2 type of count:

1. self count
2. total count

Same with call element id map, we use comma to separate data, and one line represents one call element data.
Here we use call element id instead of call element string to reference the call element.
The line looks like this: <call element id>,<self count>,<total count>

### call graph

SamplingProf collects counts of function calls. One function call is A call element calls B call element, and B call element calls A call element is considered as another function call.

The call graph stores the counts of function calls.
Every line is one function call data.
the line looks like this: <call element id1>,<call element id2>,<count>

Direct recursive calls are recorded as: <call element id1>,<call element id1>,<count>

Indirect recursive calls are ignored as function call only have direct call info. Hence the data maybe odd when there are indirect recursive calls.
