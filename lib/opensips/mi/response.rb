module Opensips
  module MI
    class Response
      attr_reader :code, :success, :message
      attr_reader :rawdata # raw data array
      attr_reader :result  # formatted data

      def initialize(data)
        raise InvalidResponseData, 
          'Invalid parameter' unless data.is_a? Array
        raise EmptyResponseData, 
          'Empty parameter array' if data.empty?
        
        if /^(?<code>\d+) (?<message>.+)$/ =~ data.shift.to_s
          @code = code.to_i
          @message = message
        else
          raise InvalidResponseData,
            'Invalid response parameter. Can not parse'
        end

        @success = (200..299).include?(@code)

        # successfull responses have additional new line
        data.pop if @success
        @rawdata = data
        @result = nil
      end
      
      # Parse user locations records to Hash
      def ul_dump
        return nil unless /^Domain:: location table=\d+ records=(\d+)$/ =~ @rawdata.shift
        records = Hash.new
        aor = ''
        @rawdata.each do |r|
          if /\tAOR:: (?<peer>.+)$/ =~ r
            aor = peer
            records[aor] = Hash.new
          end
          if /^\t{2,3}(?<key>[^:]+):: (?<val>.*)$/ =~ r
            records[aor][key] = val if aor
          end
        end
        @result = records
        self
      end

      # returns struct
      def uptime
        res = Hash.new
        @rawdata.each do |r|
          next if /^Now::/ =~ r
          if /^Up since:: [^\s]+ (?'mon'[^\s]+)\s+(?'d'\d+) (?'h'\d+):(?'m'\d+):(?'s'\d+) (?'y'\d+)/ =~ r
            res[:since] = Time.local(y,mon,d,h,m,s)
          end
          if /^Up time:: (?'sec'\d+) / =~ r
            res[:uptime] = sec.to_i
          end
        end
        @result = OpenStruct.new res
        self
      end

      # returns struct
      def cache_fetch
        res = Hash.new
        @rawdata.each do |r|
          if /^(?'label'[^=]+)=\s+\[(?'value'[^\]]+)\]/ =~ r
            label.strip!
            res[label.to_sym] = value
          end
        end
        @result = OpenStruct.new res
        self
      end
      
      # returns Array of registered contacts
      def ul_show_contact
        res = Array.new
        @rawdata.each do |r|
          cont = Hash.new
          r.split(?;).each do |rec|
            if /^Contact:: (.*)$/ =~ rec
              cont[:contact] = $1
            else
              key,val = rec.split ?=
              cont[key.to_sym] = val
            end
          end
          res << cont
        end
        @result = res
        self
      end

      # returns hash of dialogs
      def dlg_list
        # parse dialogs information into array
        # assuming new block always starts with "dialog::  hash=..."
        calls, key = Hash.new, nil
        @rawdata.each do |l|
          l.strip!
          if l.match(/^dialog::\s+hash=(.*)$/)
            key = $1
            calls[key] = Hash.new
            next
          end
          # building dialog array
          if l.match(/^([^:]+)::\s+(.*)$/)
            calls[key][$1.to_sym] = $2
          end
        end
        @result = calls
        self
      end

    end

    class InvalidResponseData < Exception;end
    class EmptyResponseData < Exception;end
  end
end
