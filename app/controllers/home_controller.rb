require 'open-uri'

require 'RMagick'

class HomeController < ApplicationController
  def index

  	logger.info '*******'
  	logger.info asset_path
  	logger.info '*******'

  	# Set meta tags
    set_meta_tags :title => "Where on Earth is the temperature similar to Mars?",
                  :description => "A 2013 NASA SpaceApps Challenge observing the temperature & wind speed on Mars and trying to match it with somewhere on Earth.",
                  :keywords => "mearth, mars, earth, spaceapps, adelaide, hackerspace, australia, spaceapps_adl, nasa, curiosity, rover",
                  :canonical => root_url,
                  :open_graph => {
                    :title => "Where on Earth is the temperature similar to Mars?",
                    :description => "A 2013 NASA SpaceApps Challenge observing the temperature & wind speed on Mars and trying to match it with somewhere on Earth.",
                    :url   => root_url,
                    :image => URI.join(root_url, view_context.image_path('mearth@2x.png')),
                    :site_name => "Mearth"
	}

    def celcius_to_kelvin(celcius)
      return celcius+273
    end

    def get_mars_wx
      Rails.cache.fetch("mars_wx",:expires_in => 5.minutes) do
        open("http://cab.inta-csic.es/rems/rems_weather.xml").read
      end
    end

    def get_cities_wx
      Rails.cache.fetch("cities_wx",:expires_in => 5.minutes) do
        open("http://openweathermap.org/data/2.1/find/city?format=json&bbox=-180,-90,180,90").read
      end
    end

    #parse mars weather data
    mars_wx = Nokogiri.XML(get_mars_wx)

    @mars_min = celcius_to_kelvin(mars_wx.at_xpath("//min_temp").text.to_f)
    @mars_max = celcius_to_kelvin(mars_wx.at_xpath("//max_temp").text.to_f)

    @mars_atmo = mars_wx.at_xpath("//atmo_opacity").text
    @mars_wind_speed = mars_wx.at_xpath("//wind_speed").text.to_f

    cities = JSON.parse(get_cities_wx)
  
    min = cities["list"].min{|a,b| (a["main"].try(:[],"temp_min").to_f) <=> (b["main"].try(:[],"temp_min").to_f)}["main"]["temp_min"].to_f
    max = cities["list"].max{|a,b| (a["main"].try(:[],"temp_max").to_f) <=> (b["main"].try(:[],"temp_max").to_f)}["main"]["temp_max"].to_f

 
    @mars_avg = (@mars_min+@mars_max)/2.0

    def avg(city)
      return (city["main"].try(:[],"temp_min").to_f+city["main"].try(:[],"temp_max").to_f)/2.0
    end

    @closest = cities["list"].min do |a,b| 

      def dist(city)
        return (avg(city)-@mars_max).abs
      end

      dist(a) <=> dist(b)
    end

    @closest_avg = avg(@closest)
  
    #logger.info(@closest)

    height = cities["list"].length

    canvas = Magick::Image.new(max, height,
              Magick::HatchFill.new('white','lightcyan2')) 
    canvas.format = "JPEG"
    gc = Magick::Draw.new

    #gc.stroke('transparent')
    #gc.fill('#202123')
    #gc.pointsize('11')
    #gc.font_family = "helvetica"
    #gc.font_weight = Magick::BoldWeight
    #gc.font_style  = Magick::NormalStyle
    #cities["list"].each{|c| gc.text(x=c["coord"]["lon"]+180,y=c["coord"]["lat"]+90,text=c["name"])}
    #cities["list"].each{|c| gc.point(x=c["coord"]["lon"]+180,y=90-c["coord"]["lat"])}

    gc.stroke("red")
    gc.line(@mars_min,0,@mars_min,height)
    gc.line(@mars_max,0,@mars_max,height)

    @index=0
    cities["list"].each do |c| 
      if (c==@closest)
        gc.stroke("pink")
        gc.line(0,@index,max,@index)
      end
      gc.stroke("black")
      gc.line(c["main"]["temp_min"],@index,c["main"]["temp_max"],@index)

      gc.fill("green")
      gc.stroke("green")
      #logger.info(avg(c))
      gc.point(avg(c),@index)
      #fscking evil
      @index+=1
    end
    #gc.text(x = 83, y = 14, text = "foobar")
    gc.draw(canvas)
    
    @data_uri = Base64.encode64(canvas.to_blob).gsub(/\n/, "")  
  end
end
