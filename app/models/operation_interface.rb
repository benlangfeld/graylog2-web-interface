class OperationInterface

  ALLOWED_OPERATIONS = %w(count find distinct)

  def get_all
    res = Array.new
    ops["inprog"].each do |op|
      next if !allowed_op?(op)

      res << {
        :opid => op["opid"],
        :secs_running => op["secs_running"],
        :type => extract_type(op),
        :query => extract_query(op)
      }
    end

    return res
  rescue => e
    Rails.logger.error "Could not get current operations: #{e.message + e.backtrace.join("\n")}"
    return Array.new
  end

  def count
    get_all.count
  end

  def kill(opid)
    op = ops["inprog"].keep_if{ |o| o["opid"] == opid.to_i }.first
    return false if op.blank? || !allowed_op?(op)
    Mongoid.database["$cmd.sys.killop"].find_one({:op => opid.to_i})

    true
  end

  private

  def ops
    Mongoid.database["$cmd.sys.inprog"].find_one
  end

  def allowed_op?(op)
    return false unless op["ns"] =~ /^#{Mongoid.database.name}/ # Only graylog2 database.
    return false unless op["op"] == "query" # Only query operations.
    return false unless ALLOWED_OPERATIONS.include?(extract_type(op)) # Only count, find or distinct queries.

    return true
  rescue => e
    Rails.logger.error "Could not check if operation is allowed: #{e.message + e.backtrace.join("\n")}"
    return false
  end

  def extract_type(op)
    if op["query"]["$query"].blank?
      # This is not a find query.
      op["query"].keys.first
    else
      "find"
    end 
  end

  # ZOMG mongodb naming
  def extract_query(op)
    op["query"]["$query"].blank? ? op["query"]["query"] : op["query"]["$query"]
  end

end
