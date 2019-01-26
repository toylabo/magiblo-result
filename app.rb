# coding: utf-8

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'rqrcode'
require 'rqrcode_png'
require './models/player.rb'
require 'date'
require 'dropbox_api'
require 'chunky_png'
require 'rack/contrib'
require 'json'
require './twit'
require 'RMagick'
require 'to-bool'
require 'will_paginate/view_helpers/sinatra'
require 'will_paginate/active_record'

client = DropboxApi::Client.new('oV2_fiUN1mAAAAAAAAAACSGg9RfeIPV7vGhAWevSQ_uxACHGUBDX9jESrVdzd1_I')
use Rack::PostBodyContentTypeParser

get '/' do
    "QRコードから結果を読み取ってください。"
end

get '/result' do
    "idがありません。"
end

get '/result/:id' do
    unless params[:id].nil?
    
        begin
            @player = Player.find(params[:id])
        rescue => error
            error_missing_player
        end

        if @player.present?
            @id = @player.id
            @name = @player.name
            @score_VR = @player.scoreVR
            @score_2D = @player.score2D
            @total = @player.total
            @result_VR = @player.isWinVR.to_s.downcase
            @result_2D = @player.isWin2D.to_s.downcase
            @chara_VR = @player.charaVR.downcase
            @chara_2D = @player.chara2D.downcase
            @restless_str = @player.restlessStr
            @effort_str = @player.effortStr

            json_comments = open('./public/comments.json') do |io|
                JSON.load(io)
            end
            
            @chara_VR_JPN = json_comments[@chara_VR]['nameJPN']
            @chara_2D_JPN = json_comments[@chara_2D]['nameJPN']

            @comment_VR = json_comments[@chara_VR]['messages'][@result_VR]
            @comment_2D = json_comments[@chara_2D]['messages'][@result_2D]


            json_eval = open('./public/eval.json') do |io|
                JSON.load(io)
            end

            if isWin?(@result_VR) && isWin?(@result_2D)
                @eval_messages = json_eval[0]
            elsif isWin?(@result_VR) && !(isWin?(@result_2D))
                @eval_messages = json_eval[1]
            elsif !(isWin?(@result_VR)) && isWin?(@result_2D)
                @eval_messages = json_eval[2]
            elsif !(isWin?(@result_VR)) && !(isWin?(@result_2D))
                @eval_messages = json_eval[3]
            end

            @today_players = Player.where(updated_at: Date.today.beginning_of_day.in_time_zone('UTC').to_time..
                                         Date.today.end_of_day.in_time_zone('UTC').to_time).
                                         order('total DESC')

            @players = Player.order('total DESC')

            @all_players_rank = Player.where("total > ?", @player.total).count + 1
            @today_players_rank = @today_players.where("total > ?", @today_players.total).count + 1

            @ogp_meta = makeOGPMeta(@id,@name,@total)
            makeOGP(@id,@name,@score_VR,@score_2D,isWin?(@result_VR),isWin?(@result_2D),@chara_VR,@chara_2D,@comment_VR,@comment_2D,@all_player_rank,@today_rank,@restless_str,@effort_str)
            @twitter_anchor = makeTweetLink(@id,@name,@total)

            erb:index
        else
            error_missing_player
        end
    else
        error_missing_player
    end
end

get ['/recent', '/recent/', '/recent/:id'] do
    params[:id] = 10 if params[:id].nil?
    @recent_players = Player.order('updated_at DESC').limit(params[:id])
    erb:recent
end

get ['/ranking', '/ranking/', '/ranking/:id'] do
    params[:id] = 10 if params[:id].nil?
    @players = Player.order('total DESC').limit(params[:id])
    erb:ranking
end

post '/qr' do
    @name = params[:name]
    @score_VR = params[:scoreVR].to_i
    @score_2D = params[:score2D].to_i
    @total = @score_VR + @score_2D
    @result_VR = params[:isWinVR]
    @result_2D = params[:isWin2D]
    @chara_VR = params[:charaVR]
    @chara_2D = params[:chara2D]

    @chara_2D = 'jasmine' if @chara_2D == 'jasmin'

    evaluation(params[:moveCount].to_i, @total)
    @player = Player.new(name: @name, scoreVR: @score_VR, score2D: @score_2D, total: @total, isWinVR: @result_VR,
                            isWin2D: @result_2D, charaVR: @chara_VR, chara2D: @chara_2D, restlessStr: @restless_str, effortStr: @effort_str)
    begin
        @player.save
    rescue => error
        return error
    end
    
    @url = url(@player.id)
    qr = RQRCode::QRCode.new(@url, :size => 7, :level => :m)
    @qr = qr.to_img.resize(600,600)
    @path = "public/qr/#{@player.id}.png"
    @qr.save(@path)
    file_content = IO.read(@path)
    client.upload "/#{@player.id}.png", file_content, :mode => :overwrite
    @link = client.create_shared_link_with_settings("/#{@player.id}.png")
    @qr_url = @link.url.sub(/www.dropbox.com/, "dl.dropboxusercontent.com").sub(/\?dl=0/, "")
    puts @qr_url
    erb:qr2
end

get '*' do
    return "404 Not Found"
end

helpers do
    def error_missing_player
        "URLが間違っているか、データが登録されていない可能性があります。"
    end

    def link_to(url, text=url)
        "<a href=\"#{url}\">#{text}</a>"
    end

    def url(id)
        if settings.production?
            "https://result-magiblo.herokuapp.com/result/" + id.to_s
        elsif settings.test?
            "https://result-magiblo-dev.herokuapp.com/result/" + id.to_s
        else
            "localhost:4567/result/" + id.to_s
        end
    end

    def evaluation(move_count,total)

        if move_count.div(6) <= 0
            @restless_str_count = 1
        elsif move_count.div(6) > 5
            @restless_str_count = 5
        else
            @restless_str_count = move_count.div(6)
        end

        @restless_str = ""
        @restless_str_count.times do
            @restless_str += "★"
        end

        @restless_str += "☆" * (5 - @restless_str_count)

        if total.div(250) <= 0
            @effort_str_count = 1
        elsif total.div(250) > 5
            @effort_str_count = 5            
        else
            @effort_str_count = total.div(250)
        end

        @effort_str = ""
        @effort_str_count.times do
            @effort_str += "★"
        end

        @effort_str += "☆" * (5 - @effort_str_count)

    end

     def isWin?(result)
        if result == "win"
            true
        elsif result == "lose"
            false
        end
    end

    def checkParamsNil?(params)
        params.each do |param|
            return true if param.nil?
        end
        return false
    end

end
