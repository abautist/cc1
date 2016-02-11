require 'logger'

# Global variables
cpu_threshold = 80  # %age of cpu that we should be alerting at
cpu_tries = 5
cpu_wait = 30

memory_threshold = 80 # %age of memory that we should be alerting at
memory_tries = 5
memory_wait = 30

$pagerduty_api_key = ENV['PAGERDUTY_API_KEY']

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

def get_cpu
  # Get current cpu usage - let's check usage and iowait
  # TODO: we want to check all cpu states
  mpstat_out = `/usr/bin/mpstat | grep all`
  mpstat_out_ary = mpstat_out.split(' ')

  cpu_usage = mpstat_out_ary[3]

  return cpu_usage.to_f
end

def getmemory
  # Get memory usage
  free_out = `/usr/bin/free|grep ^Mem`

  used = free_out.split(' ')[2].to_f
  total = free_out.split(' ')[1].to_f

  return (used / total) * 100
end

logger.info("Checking cpu utilization")
cpu_usage = get_cpu()

# If the cpu is over the threshold, then keep checking
if cpu_usage > cpu_threshold
  logger.info("CPU is over threshold, continuing to check")
  cpu_over = 1

  for i in 0..cpu_tries
    logger.info("CPU check try #{i}")
    if(get_cpu > cpu_threshold)
      cpu_over = cpu_over + 1
    end
    logger.info("Sleeping for #{cpu_wait} seconds")
    sleep(cpu_wait)
  end

    if cpu_over > cpu_tries
      # Let's alert on this
      logger.info("CPU is over, alerting via pagerduty")
      pagerduty = Pagerduty.new($pagerduty_api_key)
      incident = pagerduty.trigger("CPU is high: #{cpu_usage}")
    end
end

# memory checks
logger.info("Checking memory")
mem_usage = getmemory()

if mem_usage > memory_threshold
   logger.info("Mem is over threshold, continuing to check")
  mem_over = 1

  for i in 0..memory_tries
    logger.info("MEM check try #{i}")
    if(getmemory > memory_threshold)
      mem_over = mem_over + 1
    end
   logger.info("Sleeping for #{cpu_wait} seconds")
    sleep(memory_wait)
  end

  if mem_over > memory_tries
    # Let's alert on this
    logger.info("mem is over, alerting via pagerduty")
    pagerduty = Pagerduty.new($pagerduty_api_key)

    begin
      require 'sys-uname'
      incident = pagerduty.trigger(
        "Mem is high: #{mem_usage}",
         client:       Sys::Uname.nodename,
      )
    rescue Net::HTTPServerException => error
     puts "PAGERDUTY FAILED!"
      puts error.response.code
      puts error.response.message
      puts error.response.body
    end
  end
end