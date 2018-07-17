#
# Copyright 2018- Timothy Schroeder
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

require "fluent/plugin/filter"
require "yajl"

module Fluent
  module Plugin
    class SplitBySizeFilter < Fluent::Plugin::Filter
      Fluent::Plugin.register_filter("split_by_size", self)

      class SkipRecordError < ::StandardError
        def initialize(message, record)
          super message
          @record_message = if record.is_a? Array
            record.reverse.map(&:to_s).join(', ')
          else
            record.to_s
          end
        end

        def to_s
          super + ": " + @record_message
        end
      end

      class KeyNotFoundError < SkipRecordError
        def initialize(key, record)
          super "Key '#{key}' doesn't exist", record
        end
      end

      desc "Max size an event can be in bytes"
      config_param :max_event_size, :integer, default: 1024 * 1024
      desc "Field that contains a unique id that will be added to all created events"
      config_param :id_field, :string

      def configure(conf)
        super
        @max_record_size = @max_event_size - 200 # Allow space to add the id field
      end

      def filter_stream(tag, es)
        new_es = MultiEventStream.new
        es.each { |time, record|
          begin
            raise KeyNotFoundError.new(@id_field, record) if record[@id_field].nil?
            id = record.delete(@id_field)
            records = split_event(record)
            records.each { |rec|
              rec[@id_field] = id
              new_es.add(time, rec)
            }
          rescue => e
            router.emit_error_event(tag, time, record, e)
          end
        }
        new_es
      end

      def size_of_values(record)
        Yajl.dump(record).bytesize
      end

      def split_event(record)
        records = []
        if size_of_values(record) > @max_record_size
          if record.keys.count > 1
            split_records = record.split_into(2)
            split_records.each { |rec|
              records = records + split_event(rec)
            }
          else
            log.warn('Key/Value pair is too large: "%s:%s". Max size is: %s, dropping!' % [record.keys[0], record.values[0], @max_record_size])
            return []
          end
        else
          records.push(record)
        end
        records
      end

      Hash.class_eval do
        def split_into(divisions)
          count = 0
          inject([]) do |final, key_value|
            final[count%divisions] ||= {}
            final[count%divisions].merge!({key_value[0] => key_value[1]})
            count += 1
            final
          end
        end
      end
    end
  end
end
