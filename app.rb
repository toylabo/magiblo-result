require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'rqrcode'
require 'rqrcode_png'
require './models/player.rb'
require 'date'

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
            erb:result
        else
            error_missing_player
        end
    else
        error_missing_player
    end
end

post '/qr' do
    @name = params[:name]
    @score_VR = params[:scoreVR].to_i
    @score_2D = params[:score2D].to_i
    @total = @score_VR + @score_2D
    @player = Player.new(name: @name, scoreVR: @score_VR, score2D: @score_2D, total: @total)
    @player.save
    @url = "https://result-magiblo.herokuapp.com/result/#{@player.id}"
    #@url = "localhost:4567/result/#{player.id}"
    qr = RQRCode::QRCode.new(@url, :size => 7, :level => :h)
    @png = qr.to_img
    @path = "public/qr/#{@player.id}.png"
    @png.resize(200,200).save(@path)
    @path
end

get '*' do
    return "404 Not Found"
end

helpers do
    def error_missing_player
        "URLが間違っているか、データが登録されていない可能性があります。"
    end
end
