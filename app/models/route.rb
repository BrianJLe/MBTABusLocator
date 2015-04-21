require 'onebusaway'

class Route < ActiveRecord::Base
	attr_accessible :bus_id, :name, :latitude, :longitude

def initialize
	Onebusaway.api_key = 'TEST'
end

def self.find_buses(route)
	@route = route
	@stops = Onebusaway.stops_for_route(:id => @route)

	@trips = Onebusaway.trips_for_route(:id => @route)
	@trip_hash = Hash[@trips.map { |u| [u.id, u] }]

	@stops.each do |stop|
		@arrivals = Onebusaway.arrivals_and_departures_for_stop(:id => stop.id)

		@route_list = @arrivals.select { |obj| obj.routeId == route}
		@route_list.each do |trip|
			@trip_hash[trip.tripId] = trip unless trip.lat.nil?
		end
	end
	@trip_hash
end

end
