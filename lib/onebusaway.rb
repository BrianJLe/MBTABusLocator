require 'rexml/document'
require 'net/http'

module Onebusaway

  API_BASE = "http://developer.onebusaway.org/mbta-api/api/where/"

  class << self
    def api_key=(key)
      @api_key = key
    end

    def stop_by_id(params)
      raise if params[:id].nil?

      xml = request('stop', params)
      stop = Stop.from_xml(xml)
    end

    def route_by_id(params)
      raise if params[:id].nil?

      xml = request('route', params)
      route = Route.from_xml(xml)
    end

    def stops_for_location(params)
      raise if params[:lat].nil? || params[:lon].nil?

      doc = request('stops-for-location', params)
      stops = []
      doc.elements.each("stops/stop") do |stop_el|
        stops << Stop.from_xml(stop_el)
      end
      stops
    end

    def routes_for_location(params)
      raise if params[:lat].nil? || params[:lon].nil?

      doc = request('routes-for-location', params)
      routes = []
      doc.elements.each("routes/route") do |route_el|
        routes << Route.from_xml(route_el)
      end
      routes
    end

    def stops_for_route(params)
      raise if params[:id].nil?

      doc = request('stops-for-route', params)
      stops = []

      doc.elements.each("//stops/stop") do |stop_el|
        stops << Stop.from_xml(stop_el)
      end
      stops
    end

    def routes_for_agency(params)
      raise if params[:id].nil?

      doc = request('routes-for-agency', params)
      routes = []
      doc.elements.each("//route") do |route_el|
        routes << Route.from_xml(route_el)
      end
      routes
    end

    def trips_for_route(params)
      raise if params[:id].nil?

      doc = request('trips-for-route', params)
      trips = []
      doc.elements.each("//trips/trip") do |trip_el|
        trips << Trip.from_xml(trip_el)
      end
      trips
    end

    def arrivals_and_departures_for_stop(params)
      raise if params[:id].nil?

      doc = request('arrivals-and-departures-for-stop', params)
      arrivals = []
      doc.elements.each("//arrivalsAndDepartures/arrivalAndDeparture") do |arrival_el|
        arrivals << ArrivalAndDeparture.from_xml(arrival_el)
      end
      arrivals
    end

    private

    def api_url(call, options = {})
      url = API_BASE + call
      id = options.delete(:id)
      if id
        url += "/" + id
      end
      url += ".xml?"
      options[:key] = @api_key
      url += options.to_a.map{|pair| "#{pair[0]}=#{pair[1]}"}.join("&")
      url
    end

    def request(call, url_options)
      url = api_url(call, url_options)
      xml_data = Net::HTTP.get_response(URI.parse(url)).body

      doc = REXML::Document.new(xml_data)
      root = doc.root
      status_code = root.elements["code"].text
      status_text = root.elements["text"].text

      # failed status
      unless /2\d{2}/.match(status_code)
        raise "Request failed (#{status_code}): #{status_text}"
      end

      return root.elements["data"]
    end

  end

  class Base
    def self.from_xml(xml_or_data)
      xml_or_data = REXML::Document.new(xml_or_data).root if xml_or_data.is_a?(String)
      self.parse(xml_or_data)
    end

    def self.parse(data)
      raise "not implemented"
    end
  end

  class Agency < Base
    attr_accessor :id, :name, :url, :timezone, :lang, :phone
    def self.parse(data)
      agency = self.new
      [:id, :name, :url, :timezone, :lang, :phone].each do |attr|
        value = data.elements[attr.to_s]
        agency.send("#{attr}=", value.text) if value
      end
      agency
    end
  end

  class ArrivalAndDeparture < Base
    attr_accessor :routeId, :routeShortName, :tripId, :tripHeadsign, :stopId, :predictedArrivalTime, :scheduledArrivalTime, :predictedDepartureTime, :scheduledDepartureTime, :status, :tripStatus, :lat, :lon
    def self.parse(data)
      arrival = self.new
      [:routeId, :routeShortName, :tripId, :tripHeadsign, :stopId, :predictedArrivalTime, :scheduledArrivalTime, :predictedDepartureTime, :scheduledDepartureTime, :status, :lat, :lon].each do |attr|
        if(attr.to_s == 'lat')
          value = data.elements["tripStatus/position/lat"]
        elsif(attr.to_s == 'lon')
          value = data.elements["tripStatus/position/lon"]
        else
          value = data.elements[attr.to_s]
        end
        arrival.send("#{attr}=", value.text) if value
      end
      arrival
    end

    class TripStatus < Base
      attr_accessor :lat, :long, :orientation
      def self.parse(data)
        tripStatus = self.new
        [:lat, :long, :orientation].each do |attr|
          value = data.elements[attr.to_s]
          tripStatus.send("#{attr}=", value.text) if value
        end
        status
      end
    end

    def minutes_from_now
      @minutes_from_now ||= begin
        at = predictedArrivalTime.to_i
        if at == 0
          # no predicted time, use scheduled
          (scheduledArrivalTime.to_i/1000 - Time.now.to_i) / 60
        else
          (predictedArrivalTime.to_i/1000 - Time.now.to_i) / 60
        end
      end
      @minutes_from_now
    end
  end

  class EncodedPolyline < Base
    attr_accessor :points, :length, :levels
  end

  class Route < Base
    attr_accessor :id, :shortName, :longName, :description, :type, :url, :agency
    def self.parse(data)
      route = self.new
      [:id, :shortName, :longName, :description, :type, :url].each do |attr|
        value =  data.elements["entry"].nil? ? data.elements[attr.to_s] : data.elements["entry"].elements[attr.to_s]
        route.send("#{attr}=", value.text) if value
      end
      #route.agency = Agency.parse(data.elements["agency"])
      route
    end
  end

  class Stop < Base
    attr_accessor :id, :lat, :lon, :direction, :name, :code, :locationType, :routes
    def self.parse(data)
      stop = self.new
      [:id, :lat, :lon, :direction, :name, :code, :locationType].each do |attr|
        value = data.elements[attr.to_s]
        stop.send("#{attr}=", value.text) if value
      end
      stop.routes ||= []
      data.elements.each("//routes/route") do |route_el|
        stop.routes << Route.parse(route_el)
      end
      stop
    end
  end

  class Trip < Base
    attr_accessor :id, :routeId, :tripHeadsign, :directionId, :routes
    def self.parse(data)
      trip = self.new
      [:id, :routeId, :tripHeadsign, :directionId].each do |attr|
        value = data.elements[attr.to_s]
        trip.send("#{attr}=", value.text) if value
      end
      trip.routes ||= []
      data.elements.each("//routes/route") do |route_el|
        trip.routes << Route.parse(route_el)
      end
      trip
    end
  end

end