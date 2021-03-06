class WelcomeController < ApplicationController
  def inc
    require 'koala'
    @oauth = Koala::Facebook::OAuth.new(getconfig('fb_app_id'), getconfig('fb_app_secret'), request.original_url)
    if request.GET['code']
      setup
    else
      if getconfig('fb_user_access_token') == '0' || getconfig('fb_page_access_token') == '0'
        if getconfig('fb_app_id') == '0'
          @output = "Please insert app id/keys"
        else
          @output = "<a href='#{@oauth.url_for_oauth_code(:permissions => "pages_show_list,pages_manage_cta,read_insights,manage_pages,publish_pages,publish_actions,business_management,user_managed_groups,user_videos,user_events")}''>FB Auth 1</a>"
          @output = @output.html_safe
        end
      else
        @graph_user = Koala::Facebook::API.new(getconfig('fb_user_access_token'))
        @graph_page = Koala::Facebook::API.new(getconfig('fb_page_access_token'))
        @output = "You are authed with FB now!"
        if request.original_fullpath == "/"
          redirect_to "/eventslides"
        end
      end
    end
  end

  def index
    inc
  end

  def livestream
    inc
    @live_video_result = @graph_page.put_connections(
      getconfig('fb_page_id'),
      "live_videos",
    #  #:content_tags => '',
      :description => 'This is Davids Long desc of this video!!',
    #  :is_audio_only => 0,
    #  #:planned_start_time => "",
    #  #:privacy => '',
      :save_vod => true,
    #  #:schedule_custom_profile_image => '',
      :status => 'LIVE_NOW',
    #  :stop_on_delete_stream => 'true',
      :stream_type => 'REGULAR',
      :title => 'Davids Test Video'
    )
    @output = @live_video_result['stream_url']
  end

  def eventslides
    inc
    @outputEvents = []
    events = @graph_page.get_connections(getconfig('fb_page_id'),'events')
    events.each do |event|
      unless event['end_time'].nil?
        endTime = Time.parse(event['end_time'].to_s)
        if endTime.to_i > Time.now.to_i
          eventInfo = {
            :name => event['name'],
            :cover => @graph_page.get_object(event["id"],{fields:['cover']})['cover']['source']
          }
          startTime = Time.parse(event['start_time'].to_s)
          if endTime.strftime("%m/%d/%y") == startTime.strftime("%m/%d/%y")
            #eventInfo[:time] = "#{startTime.strftime("%A %B, #{startTime.day.ordinalize} from %I:%m")} to #{endTime.strftime("%I:%m %p")}"
            eventInfo[:time] = startTime
          else
            eventInfo[:time] = startTime
          end
          @outputEvents << eventInfo
        end
      end
    end
    #logger.debug @outputEvents.to_yaml
    # setup countdown timer
    @outputTimer = nil
    times = eval(getconfig('service_times'))
    times.each do |time|
      nextServciceTime = DateTime.now.beginning_of_week(start_day = :sunday) + time[:days].days + time[:hours].hours + time[:minutes].minutes
      timeToNextServiceTime = nextServciceTime.to_i - DateTime.now.to_i
      if timeToNextServiceTime <= 0
        timeToNextServiceTime = timeToNextServiceTime + 1.week
      end
      if @outputTimer.nil? || @outputTimer.to_i > timeToNextServiceTime.to_i
        @outputTimer = timeToNextServiceTime
      end
    end
    #if @outputTimer > 3.hours.to_i
    #  @outputTimer = nil
    #end
    logger.debug @outputTimer
  end

  def setup
    logger.debug request.GET['code']
    setconfig('fb_user_access_token',@oauth.get_access_token(request.GET['code']))
    @graph_user = Koala::Facebook::API.new(getconfig('fb_user_access_token'))
    #logger.debug getconfig('fb_page_id')
    logger.debug getconfig('fb_user_access_token')
    setconfig('fb_page_access_token',@graph_user.get_page_access_token(getconfig('fb_page_id')))
    redirect_to "/eventslides"
  end

  private
  def getconfig(configname)
    thisconfig = Config.where(:name => configname)
    if thisconfig.count == 1
      return thisconfig.first.value
    else
      return '0'
    end
  end

  def setconfig(configname,configvalue)
    if getconfig configname == 0
      Config.new(:name => configname, :value=> configvalue).save
    else
      thisconfig = Config.where(:name => configname)
      thisconfig.update(value: configvalue)
    end
  end
end
