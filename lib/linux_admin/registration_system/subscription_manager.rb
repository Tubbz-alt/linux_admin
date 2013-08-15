require 'date'

class LinuxAdmin
  class SubscriptionManager < RegistrationSystem

    def validate_credentials(options)
      !!organizations(options)
    end

    def registered?
      run("subscription-manager identity").exit_status == 0
    end

    def refresh
      run!("subscription-manager refresh")
    end

    def organizations(options)
      raise ArgumentError, "username and password are required" unless options[:username] && options[:password]
      cmd = "subscription-manager orgs"

      params = {"--username=" => options[:username], "--password=" => options[:password]}
      params.merge!(proxy_params(options))
      params["--serverurl="]  = options[:server_url]  if options[:server_url]

      output = run!(cmd, :params => params).output
      parse_output(output).index_by {|i| i[:name]}
    end

    def register(options)
      raise ArgumentError, "username and password are required" unless options[:username] && options[:password]
      cmd = "subscription-manager register"

      params = {"--username=" => options[:username], "--password=" => options[:password]}
      params.merge!(proxy_params(options))
      params["--org="]        = options[:org]         if options[:server_url] && options[:org]
      params["--serverurl="]  = options[:server_url]  if options[:server_url]

      run!(cmd, :params => params)
    end

    def subscribe(options)
      cmd    = "subscription-manager attach"
      pools  = options[:pools].collect {|pool| ["--pool", pool]}
      params = proxy_params(options).to_a + pools

      run!(cmd, :params => params)
    end

    def available_subscriptions
      cmd     = "subscription-manager list --all --available"
      output  = run!(cmd).output
      parse_output(output).index_by {|i| i[:pool_id]}
    end

    private

    def parse_output(output)
      # Strip the 3 line header off the top
      content = output.split("\n")[3..-1].join("\n")
      parse_content(content)
    end

    def parse_content(content)
      # Break into content groupings by "\n\n" then process each grouping
      content.split("\n\n").each_with_object([]) do |group, group_array|
        group = group.split("\n").each_with_object({}) do |line, hash|
          next if line.blank?
          key, value = line.split(":", 2)
          hash[key.strip.downcase.tr(" -", "_").to_sym] = value.strip
        end
        group_array.push(format_values(group))
      end
    end

    def format_values(content_group)
      content_group[:ends] = Date.strptime(content_group[:ends], "%m/%d/%Y") if content_group[:ends]
      content_group
    end

    def proxy_params(options)
      config = {}
      config["--proxy="]          = options[:proxy_address]   if options[:proxy_address]
      config["--proxyuser="]      = options[:proxy_username]  if options[:proxy_username]
      config["--proxypassword="]  = options[:proxy_password]  if options[:proxy_password]
      config
    end
  end
end