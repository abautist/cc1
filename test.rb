require 'logger'
require 'pagerduty'



class Usage
  def initialize 
    @threshold = 80
    @tries = 5
    @wait = 30
    @logger = Logger.new("| tee test.log")
    @logger.level = Logger::INFO
    @pagerduty_api_key = ENV['PAGERDUTY_API_KEY']

    system "top -l 1 | grep 'CPU usage' > ./sample.txt"
    file = File.open("./sample.txt", "rb").read
    file_arr = file.split(" ")
    @cpu_usage = file_arr[4].to_f

    system "top -l 1 | grep PhysMem > ./memory.txt"
    file = File.open("./memory.txt", "rb").read
    file_arr = file.split(" ")
    used = file_arr[1].to_f
    total = file_arr[5].to_f + used
    @mem_usage = (used / total) * 100
  end

  def check_cpu
    @logger.info("Checking cpu utilization")

    if @cpu_usage > @threshold
      @logger.info("CPU is over threshold, continuing to check")
      @cpu_over = 1

      (0..@tries).each do |i|
        @logger.info("CPU check try #{i}")
        if @cpu_usage > @threshold
          @cpu_over += 1
        end
        @logger.info("Sleeping for #{@wait} seconds")
        sleep(@wait)
      end

      if @cpu_over > @tries
        @logger.info("CPU is over, alerting via pagerduty")
        pagerduty = Pagerduty.new(@pagerduty_api_key)
        begin
          incident = pagerduty.trigger("CPU is high: #{@cpu_usage}")
        rescue Net::HTTPServerException => error
          puts "PAGERDUTY FAILED!"
          puts error.response.code
          puts error.response.message
          puts error.response.body
        end
      end
    end
  end

  def check_memory
    @logger.info("Checking memory")

    if @mem_usage > @threshold
      @logger.info("Mem is over threshold, continuing to check")
      @mem_over = 1

      (0..@tries).each do |i|
        @logger.info("MEM check try #{i}")
        if @mem_usage > @threshold
          @mem_over += 1
        end
        @logger.info("Sleeping for #{@wait} seconds")
        sleep(@wait)
      end

      if @mem_over > @tries
        @logger.info("mem is over, alerting via pagerduty")
        pagerduty = Pagerduty.new(@pagerduty_api_key)
        begin
          incident = pagerduty.trigger("Mem is high: #{@mem_usage}")
        rescue Net::HTTPServerException => error
          puts "PAGERDUTY FAILED!"
          puts error.response.code
          puts error.response.message
          puts error.response.body
        end
      end
    end
  end
end

usage = Usage.new()
puts usage.check_cpu
puts usage.check_memory
