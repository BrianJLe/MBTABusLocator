require 'onebusaway'
require 'rexml/document'
require 'json'

class RoutesController < ApplicationController
	def root

		Onebusaway.api_key = 'TEST'
		# Get all routes for agency 1, MBTA
		@routes = Onebusaway.routes_for_agency(:id => '1')

		if !params[:first_select].nil?

			# Retrieve all buses for a particular route
			@buses = Route.find_buses(params[:first_select]) 

			# Send google maps markers by lat/lon
			@hash = Gmaps4rails.build_markers(@buses.values) do |user, marker|
				if user.respond_to? :lat
					marker.lat user.lat
					marker.lng user.lon
				end
			end
		else
			@buses = Route.find_buses('1_4')

			# Send google maps markers by lat/lon
			@hash = Gmaps4rails.build_markers(@buses.values) do |user, marker|
				if user.respond_to? :lat
					marker.lat user.lat
					marker.lng user.lon
				end
			end
		end

		respond_to do |format|
			format.html
			format.json { render json: @hash }
		end
	end
end
