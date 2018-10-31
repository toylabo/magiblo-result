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

client = DropboxApi::Client.new('WkeCul5dyEAAAAAAAAAAD2PBfg0VPNVum7vz4ZzxxUXI8_n28llbMPjm4WUcayIN')
use Rack::PostBodyContentTypeParser

get '/' do
    "QRコードから結果を読み取ってください。"
end


get '/result' do
    "idがありません。"
end

get '/result/:id' do
    if !params[:id].nil?

        begin
            @player = Player.find(params[:id])
        rescue => error
            error_missing_player
        end

        if @player.present?
            @name = @player.name
            @score_VR = @player.scoreVR
            @score_2D = @player.score2D
            @total = @player.total
            @is_win_VR = @player.isWinVR
            @is_win_2D = @player.isWin2D
            @chara_VR = @player.charaVR
            @chara_2D = @player.chara2D
            @restless_str = @player.restlessStr
            @effort_str = @player.effortStr

            json_comments = open('./public/comments.json') do |io|
                JSON.load(io)
            end

            @chara_VR_JPN = json_comments[@chara_VR]['nameJPN']
            @chara_2D_JPN = json_comments[@chara_2D]['nameJPN']

            if @is_win_VR
                @comment_VR = json_comments[@chara_VR]['messages']['win']
                @result_VR = "win"
            else
                @comment_VR = json_comments[@chara_VR]['messages']['lose']
                @result_VR = "lose"
            end

            if @is_win_2D
                @comment_2D = json_comments[@chara_2D]['messages']['win']
                @result_2D = "win"
            else
                @comment_2D = json_comments[@chara_2D]['messages']['lose']
                @result_2D = "lose"
            end

            json_eval = open('./public/eval.json') do |io|
                JSON.load(io)
            end

            if @is_win_VR && @is_win_2D
                @eval_messages = json_eval[0]
            elsif @is_win_VR && !(@is_win_2D)
                @eval_messages = json_eval[1]
            elsif !(@is_win_VR) && @is_win_2D
                @eval_messages = json_eval[2]
            elsif !(@is_win_VR) && !(@is_win_2D)
                @eval_messages = json_eval[3]
            end

            today_players = Player.where(updated_at: Date.today.beginning_of_day.to_time..
                                         Date.today.end_of_day.to_time).
                                         order('total DESC')
            @players = Player.order('total DESC')

            @players.each.with_index(1) do |player,index| 
                @all_player_rank = index if @player.id == player.id
            end

            today_players.each.with_index(1) do |player,index|
                @today_rank = index if @player.id == player.id
            end
            erb:index
        else
            error_missing_player
        end
    else
        error_missing_player
    end
end

get ['/qr/recent', '/qr/recent/:id'] do
    if params[:id].nil?
        params[:id] = 10
    end
    @recent_players = Player.order('updated_at DESC').limit(params[:id])
    #@url = "https://result-magiblo.herokuapp.com/result/#{@player.id}"
    #@url = "localhost:4567/result/#{@player.id}"
    erb:recent
end

post '/qr' do
    if params[:name].nil? || params[:scoreVR].nil? || params[:score2D].nil?
        "指定されていないパラメータがあります" 
    else
        @name = params[:name]
        @score_VR = params[:scoreVR].to_i
        @score_2D = params[:score2D].to_i
        @total = @score_VR + @score_2D
        @is_win_VR = params[:isWinVR]
        @is_win_2D = params[:isWin2D]
        @chara_VR = params[:charaVR]
        @chara_2D = params[:chara2D]
        evaluation(params[:moveCount].to_i, @total)
        @player = Player.new(name: @name, scoreVR: @score_VR, score2D: @score_2D, total: @total, isWinVR: @is_win_VR,
                             isWin2D: @is_win_2D, charaVR: @chara_VR, chara2D: @chara_2D, restlessStr: @restless_str, effortStr: @effort_str)
        @player.save
        #@url = "https://result-magiblo.herokuapp.com/result/#{@player.id}"
        #@url = "localhost:4567/result/#{@player.id}"
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
        #puts "https://dl.dropboxusercontent.com/s/#{@player.id}.png"
        erb:qr2
    end
end

get '/qr/:id' do
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
        "https://result-magiblo.herokuapp.com/result/" + id.to_s
        #"localhost:4567/result/" + id.to_s
    end


    def evaluation(move_count,total)

        if move_count.div(10) == 0
            @restless_str_count = 1
        elsif move_count.div(10) > 5
            @restless_str_count = 5
        else
            @restless_str_count = move_count.div(10)
        end

        @restless_str = ""
        @restless_str_count.times do
            @restless_str += "★"
        end

        @restless_str += "☆" * (5 - @restless_str_count)

        if total.div(500) == 0
            @effort_str_count = 1
        elsif total.div(500) > 5
            @effort_str_count = 5            
        else
            @effort_str_count = total.div(500)
        end

        @effort_str = ""
        @effort_str_count.times do
            @effort_str += "★"
        end

        @effort_str += "☆" * (5 - @effort_str_count)

    end

end
