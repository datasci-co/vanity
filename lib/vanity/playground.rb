require "uri"

module Vanity
  # Playground catalogs all your experiments. For configuration please see
  # Vanity::Configuration, for connection management, please see
  # Vanity::Connection.
  class Playground

    # Created new Playground. Unless you need to, use the global
    # Vanity.playground.
    def initialize
      @loading = []
    end

    # @deprecated
    # @see Configuration#experiments_path
    def load_path
      Vanity.configuration.experiments_path
    end

    # @deprecated
    # @see Configuration#experiments_path
    def load_path=(path)
      Vanity.configuration.experiments_path = path
    end

    # @deprecated
    # @see Configuration#logger
    def logger
      Vanity.configuration.logger
    end

    # @deprecated
    # @see Configuration#logger
    def logger=(logger)
      Vanity.configuration.logger = logger
    end

    # @deprecated
    # @see Configuration#templates_path
    def custom_templates_path
      Vanity.configuration.templates_path
    end

    def custom_templates_path=(path)
      Vanity.configuration.templates_path = path
    end

    # @deprecated
    # @see Configuration#use_js
    def use_js!
      Vanity.configuration.use_js = true
    end

    # @deprecated
    # @see Configuration#use_js
    def using_js?
      Vanity.configuration.use_js
    end

    # @deprecated
    # @see Configuration#add_participant_route
    def add_participant_path
      Vanity.configuration.add_participant_route
    end

    # @deprecated
    # @see Configuration#add_participant_route=
    def add_participant_path=(path)
      Vanity.configuration.add_participant_route=path
    end

    # @since 1.9.0
    # @deprecated
    # @see Configuration#failover_on_datastore_error
    def failover_on_datastore_error!
      Vanity.configuration.failover_on_datastore_error = true
    end

    # @since 1.9.0
    # @deprecated
    # @see Configuration#failover_on_datastore_error
    def failover_on_datastore_error?
      Vanity.configuration.failover_on_datastore_error
    end

    # @since 1.9.0
    # @deprecated
    # @see Configuration#on_datastore_error
    def on_datastore_error
      Vanity.configuration.on_datastore_error
    end

    # @deprecated
    # @see Configuration#on_datastore_error
    def on_datastore_error=(closure)
      Vanity.configuration.on_datastore_error = closure
    end

    # @since 1.9.0
    # @deprecated
    # @see Configuration#request_filter
    def request_filter
      Vanity.configuration.request_filter
    end

    # @deprecated
    # @see Configuration#request_filter=
    def request_filter=(filter)
      Vanity.configuration.request_filter = filter
    end

    # @since 1.4.0
    # @deprecated
    # @see Configuration#collecting
    def collecting?
      Vanity.configuration.collecting
    end

    # @since 1.4.0
    # @deprecated
    # @see Configuration#collecting
    def collecting=(enabled)
      Vanity.configuration.collecting = enabled
    end

    # @deprecated
    # @see Vanity#reload!
    def reload!
      Vanity.reload!
    end

    # @deprecated
    # @see Vanity#load!
    def load!
      Vanity.load!
    end

    # Returns hash of experiments (key is experiment id). This creates the
    # Experiment and persists it to the datastore.
    #
    # @see Vanity::Experiment
    def experiments
      return @experiments if @experiments

      @experiments = {}
      Vanity.logger.info("Vanity: loading experiments from #{Vanity.configuration.experiments_path}")
      Dir[File.join(Vanity.configuration.experiments_path, "*.rb")].each do |file|
        Experiment::Base.load(self, @loading, file)
      end
      @experiments
    end

    def experiments_persisted?
      experiments.keys.all? { |id| connection.experiment_persisted?(id) }
    end

    # Returns a metric (raises NameError if no metric with that identifier).
    #
    # @see Vanity::Metric
    # @since 1.1.0
    def metric(id)
      metrics[id.to_sym] or raise NameError, "No metric #{id}"
    end

    # Returns hash of metrics (key is metric id).
    #
    # @see Vanity::Metric
    # @since 1.1.0
    # @deprecated
    def metrics
      unless @metrics
        @metrics = {}
        Vanity.logger.info("Vanity: loading metrics from #{Vanity.configuration.experiments_path}/metrics")

        Dir[File.join(Vanity.configuration.experiments_path, "metrics/*.rb")].each do |file|
          Metric.load(self, @loading, file)
        end
      end
      @metrics
    end

    # Tracks an action associated with a metric.
    #
    # @example
    #   Vanity.playground.track! :uploaded_video
    #
    # @since 1.1.0
    def track!(id, count = 1)
      metric(id).track!(count)
    end

    # Determines if a user has seen one the variations
    def saw_variation_for_experiment(name, identity = nil)
      identity = set_identity(name, identity)
      # deterimine if the identity has been assigned a variation
      # if they haven't been assigned a variation then they never saw one
      connection.ab_assigned(name, identity)
    end

    def get_saw_variation_time(name, identity)
      identity = set_identity(name, identity)
      connection.get_saw_variation_time(name, identity)
    end

    def get_variation(name, identity)
      identity = set_identity(name, identity)
      variation = connection.ab_assigned(name, identity)
      if variation.nil?
        return nil
      else
        return experiment(name).alternatives[variation].value.to_s
      end
    end

    # -- Connection management --

    # This is the preferred way to programmatically create a new connection (or
    # switch to a new connection). If no connection was established, the
    # playground will create a new one by calling this method with no arguments.
    #
    # With no argument, uses the connection specified in config/vanity.yml file
    # for the current environment (RACK_ENV, RAILS_ENV or development). If there
    # is no config/vanity.yml file, picks the configuration from
    # config/redis.yml, or defaults to Redis on localhost, port 6379.
    #
    # If the argument is a symbol, uses the connection specified in
    # config/vanity.yml for that environment. For example:
    #   Vanity.playground.establish_connection :production
    #
    # If the argument is a string, it is processed as a URL. For example:
    #   Vanity.playground.establish_connection "redis://redis.local/5"
    #
    # Otherwise, the argument is a hash and specifies the adapter name and any
    # additional options understood by that adapter (as with config/vanity.yml).
    # For example:
    #   Vanity.playground.establish_connection :adapter=>:redis,
    #                                          :host=>"redis.local"
    # Returns the experiment. You may not have guessed, but this method raises
    # an exception if it cannot load the experiment's definition.
    #
    # @see Vanity::Experiment
    # @deprecated
    def experiment(name)
      id = name.to_s.downcase.gsub(/\W/, "_").to_sym
      Vanity.logger.warn("Deprecated: Please call experiment method with experiment identifier (a Ruby symbol)") unless id == name
      experiments[id.to_sym] or raise NoExperimentError, "No experiment #{id}"
    end


    # -- Participant Information --

    # Returns an array of all experiments this participant is involved in, with their assignment.
    #  This is done as an array of arrays [[<experiment_1>, <assignment_1>], [<experiment_2>, <assignment_2>]], sorted by experiment name, so that it will give a consistent string
    #  when converted to_s (so could be used for caching, for example)
    def participant_info(participant_id)
      participant_array = []
      experiments.values.sort_by(&:name).each do |e|
        index = connection.ab_assigned(e.id, participant_id)
        if index
          participant_array << [e, e.alternatives[index.to_i]]
        end
      end
      participant_array
    end

    # @since 1.4.0
    # @deprecated
    # @see Vanity::Connection
    def establish_connection(spec=nil)
      disconnect!
      Vanity.connect!(spec)
    end

    # @since 1.4.0
    # @deprecated
    # @see Vanity.connection
    def connection
      Vanity.connection.adapter
    end

    # @since 1.4.0
    # @deprecated
    # @see Vanity.connection
    def connected?
      Vanity.connection.connected?
    end

    # @since 1.4.0
    # @deprecated
    # @see Vanity.disconnect!
    def disconnect!
      Vanity.disconnect!
    end

    # Closes the current connection and establishes a new one.
    #
    # @since 1.3.0
    # @deprecated
    def reconnect!
      Vanity.reconnect!
    end
<<<<<<< HEAD
=======

    protected

    def autoconnect(options, arguments)
      if options[:redis]
        @adapter = RedisAdapter.new(:redis=>options[:redis])
      else
        connection_spec = arguments.shift || options[:connection]
        if connection_spec
          connection_spec = "redis://" + connection_spec unless connection_spec[/^\w+:/]
          establish_connection connection_spec
        else
          establish_connection
        end
      end
    end

    def set_identity(name, identity)
      if identity.nil?
        identity = experiment(name).get_identity()
      end
      return identity
    end
  end

  # In the case of Rails, use the Rails logger and collect only for
  # production environment by default.
  class << self

    # The playground instance.
    #
    # @see Vanity::Playground
    attr_accessor :playground
    def playground
      # In the case of Rails, use the Rails logger and collect only for
      # production environment by default.
      @playground ||= Playground.new(:rails=>defined?(::Rails))
    end

    # Returns the Vanity context. For example, when using Rails this would be
    # the current controller, which can be used to get/set the vanity identity.
    def context
      Thread.current[:vanity_context]
    end

    # Sets the Vanity context. For example, when using Rails this would be
    # set by the set_vanity_context before filter (via Vanity::Rails#use_vanity).
    def context=(context)
      Thread.current[:vanity_context] = context
    end


>>>>>>> add ability to ab test for multiple possible user identities
  end
end
