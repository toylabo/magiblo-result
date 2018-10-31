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
        isWin?(VR, params[:isWinVR])
        isWin?(2D, params[:isWin2D])
        charaName(VR, params[:charaVR])
        charaName(2D, params[:chara2D])
        evaluation(params[:moveCount], @total)
        @player = Player.new(name: @name, scoreVR: @score_VR, score2D: @score_2D, total: @total)
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

    def isWin?(side,result)
        if side.downcase == "vr"
            @is_win_VR ||= result
        elsif side.downcase == "2d"
            @is_win_2D ||= result
        end
    end

    def charaName(side,name="")
        if side.downcase == "vr"
            @chara_VR ||= name
        elsif side.downcase == "2d"
            @chara_2D ||= name
        end
    end

    def evaluation(move_count,total)
        if move_count/10 == 0
            @restless_str_count = 1
        elsif move_count/10 > 5
            @restless_str_count = 5
        else
            @restless_str_count = move_count / 10
        end

        @restless_str_count.times do
            @restless_str += "★"
        end

        @restless_str += "☆" * (5 - @restless_str_count)

        if total/5 == 0
            @effort_str_count = 1
        elsif total/5 > 5
            @effort_str_count = 5            
        else
            @effort_str_count = 5
        end

        @effort_str_count.times do
            @effort_str += "★"
        end

        @effort_str += "☆" * (5 - @effort_str_count)

    end

end
