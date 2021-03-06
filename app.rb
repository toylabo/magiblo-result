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
require 'will_paginate/view_helpers/sinatra'
require 'will_paginate/active_record'
require 'net/http'
require 'uri'

client = DropboxApi::Client.new

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
            @result_VR = @player.isWinVR.downcase
            @result_2D = @player.isWin2D.downcase
            @chara_VR = @player.charaVR.downcase
            @chara_2D = @player.chara2D.downcase

            json_comments = open('./public/comments.json') do |io|
                JSON.load(io)
            end
            
            @chara_VR_JPN = json_comments[@chara_VR]['name']
            @chara_2D_JPN = json_comments[@chara_2D]['name']

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
            elsif !((isWin?(@result_VR)) || (isWin?(@result_2D)))
                @eval_messages = json_eval[3]
            end

            @today_players = Player.where(updated_at: @player.updated_at.beginning_of_day.in_time_zone(ENV['TZ']).to_time..
                                          @player.updated_at.end_of_day.in_time_zone(ENV['TZ']).to_time)

            @all_players_rank = Player.where("total > ?", @player.total).count + 1
            @today_players_rank = @today_players.where("total > ?", @player.total).count + 1

            @ogp_meta = makeOGPMeta(@player.id,@player.name,@player.total)
            makeOGP(@player.id,@player.name,@player.scoreVR,@player.score2D,
                    isWin?(@result_VR),isWin?(@result_2D),@chara_VR,@chara_2D,
                    @comment_VR,@comment_2D,@all_players_rank,@today_players_rank,@player.restlessStr,@player.effortStr)
            @twitter_anchor = makeTweetLink(@player.id,@player.name,@player.total)

            erb:index
        else
            error_missing_player
        end
    else
        error_missing_player
    end
end

get ['/recent', '/recent/', '/recent/:id'] do
    @per_page = params[:per_page] || 10
    @recent_players = Player.order('id DESC').paginate(:page => params[:page], :per_page => @per_page)
    erb:recent
end

get ['/ranking', '/ranking/', '/ranking/:id'] do
    @per_page = params[:per_page] || 10
    @players = Player.order('total DESC').paginate(:page => params[:page], :per_page => @per_page)
    erb:ranking
end

get ['/ranking/date/','/ranking/date/:date'] do
    @per_page = params[:per_page] || 10
    begin
        @day = params[:date].nil? ? Date.today : params[:date].to_date
        @players = Player.where(updated_at: @day.in_time_zone('Asia/Tokyo').all_day).order('total').reverse_order.paginate(:page => params[:page], :per_page => @per_page)
    rescue => e
        halt 400, "不正な値が入力されました"
    end
    erb:today_ranking
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
    
    # puts "送られてきたやつ"
    # puts "name: #{params[:name]}"
    # puts "scoreVR: #{params[:scoreVR]}"
    # puts "score2D: #{params[:score2D]}"
    # puts "isWinVR: #{params[:isWinVR]}"
    # puts "isWin2D: #{params[:isWin2D]}"
    # puts "charaVR: #{params[:charaVR]}"
    # puts "chara2D: #{params[:chara2D]}"
    # puts "moveCount: #{params[:moveCount]}"
    # puts ""

    begin
        @player.save
    rescue ActiveModel::ValidationError => error
        halt 400, "400 Bad Request"
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
    Net::HTTP.post_form(URI.parse('https://hooks.slack.com/services/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'),{'text' => "【作成されたよ】\n#{@player.id}\n#{@url}"})
    erb:qr2
end

get '*' do
    halt 404, "404 Not Found!"
end

helpers do
    def error_missing_player
        "URLが間違っているか、データが登録されていない可能性があります。"
    end

    def link_to(url, text=url, options={})
        "<a href=\"#{url}\" #{"class=\"#{options[:class]}\"" unless options[:class].nil? } >#{text}</a>"
    end

    def image_tag(path, alt="", options={})
        "<img src=\"#{path}\" alt=\"#{alt}\" #{('class=\"'+options[:class] +'\"') unless options[:class].nil? } >"
    end

    def url(id)
        "#{ENV['DEPLOY_URL']}result/#{id}"
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

    def player_class(rank)
        case @player_rank
        when 1 then
            @player_class = "first"
        when 2 then
            @player_class = "second"
        when 3 then
            @player_class = "third"
        else
            @player_class = ""
        end
    end

    def higherChara(player)
        return player.score2D >= player.scoreVR ? player.chara2D.downcase : player.charaVR.downcase
    end

    def isWin?(result)
        if result == "win"
            true
        elsif result == "lose"
            false
        end
    end

end
