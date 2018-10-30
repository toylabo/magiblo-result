# coding: utf-8

require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'rqrcode'
require 'rqrcode_png'
require './models/player.rb'
require 'date'
require 'dropbox_api'

client = DropboxApi::Client.new('WkeCul5dyEAAAAAAAAAAD2PBfg0VPNVum7vz4ZzxxUXI8_n28llbMPjm4WUcayIN')

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
    @url = "https://result-magiblo.herokuapp.com/result/#{@player.id}"
    #@url = "localhost:4567/result/#{@player.id}"
    erb:recent
end

post '/qr' do
    @name = params[:name]
    @score_VR = params[:scoreVR].to_i
    @score_2D = params[:score2D].to_i
    @total = @score_VR + @score_2D
    @player = Player.new(name: @name, scoreVR: @score_VR, score2D: @score_2D, total: @total)
    @player.save
    @url = "https://result-magiblo.herokuapp.com/result/#{@player.id}"
    #@url = "localhost:4567/result/#{@player.id}"
    qr = RQRCode::QRCode.new(@url, :size => 7, :level => :m)
    @qr = qr.to_img.resize(600,600)
    @path = "./public/qr/#{@player.id}.png"
    @qr.save(@path)
    #erb:qr
    file_content = IO.read(@path)
    client.upload "/#{@player.id}.png", file_content
    @link = client.create_shared_link_with_settings("/#{@player.id}.png")
    @qr_url = @link.url.sub(/www.dropbox.com/, "dl.dropboxusercontent.com").sub(/\?dl=0/, "")
    #puts "https://dl.dropboxusercontent.com/s/#{@player.id}.png"
    erb:qr2
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

end
