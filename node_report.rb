#
# Author:: John Alberts (<john.m.alberts@gmail.com>)
# Copyright:: Copyright (c) 2010 John Alberts
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'
require 'highline'
require 'chef/search/query'
require 'socket'
require 'timeout'

class Chef
  class Knife
    class NodeReport < Knife
      def highline
        @h ||= HighLine.new
      end

      def is_port_open?(ip, port)
        begin
          Timeout::timeout(1) do
            begin
              s = TCPSocket.new(ip, port)
              s.close
              return true
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              return false
            end
          end
        rescue Timeout::Error
        end

        return false
      end

      def showreport(node)
        if node["ohai_time"]
          current_time = Date.today
          date = Date.parse(Time.at(node["ohai_time"]).to_s)
          hours, minutes, seconds, frac = Date.day_fraction_to_time(current_time - date)
          hours_text   = "#{hours} hour#{hours == 1 ? ' ' : 's'}"
          minutes_text = "#{minutes} minute#{minutes == 1 ? ' ' : 's'}"
          last_check_in = hours < 1 ? "#{minutes_text}" : "#{hours_text}"
          roles = node.run_list.roles.reject{|n| n =~ /lucid|cluster|ec2|gluster/}.join(",")
          status = is_port_open?("#{node.ec2.public_ipv4}","22") ? "UP" : "DOWN"
          #puts "|\t#{roles}\t|\t#{node.ec2.instance_id}\t|\t#{node.ec2.public_hostname}\t|\t#{status}\t|\t#{last_check_in}\t|"
          puts "#{roles}\t#{node.ec2.instance_id}\t#{node.ec2.public_hostname}\t#{status}\t#{last_check_in}"
          #$results << [roles,node.ec2.instance_id,node.ec2.public_hostname,status,last_check_in]
        end
      end

      def run
        tasklist = []
        #$results = []
        #$results << ["Roles","Instance ID","Public Hostname","Ping Status","Last Check-in Time"]
        #puts
        #"|\tRoles\t\t\t\t\t|\tinstance_id\t|\tpublic_hostname\t|\tPing
        #Status\t|\tlast check in time\t|"
        puts "Roles\tinstance_id\tpublic_hostname\tPing Status\tlast check in time"
        Chef::Search::Query.new.search(:node, '*:*') do |node|
          # Set the threads going

          task = Thread.new { showreport(node) }
          tasklist << task
        end
        tasklist.each { |task|
          task.join
        }
        #pp results
      end
    end
  end
end

