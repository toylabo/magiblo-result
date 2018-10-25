require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'rqrcode'
require 'rqrcode_png'
require './models/player.rb'
require 'date'

configure :production do
    ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
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
            today_players = Player.where(updated_at: Date.today.beginning_of_day.to_time..Date.today.end_of_day.to_time).
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

get '/results' do
    results.sort! do |a,b|
        b[:score] <=> a[:score]
    end
    json results
end

get '/results.json' do
    results.sort! do |a,b|
        b[:score] <=> a[:score]
    end
    json results
end

get '/score' do
    id = params['id'].to_i
    "#{results.select { |result| result[:id] == id }[0][:score]}"
end

get '/register' do
    if !params['id'].nil? && !params['name'].nil? && !params['score'].nil? && !params['side']
        id = params['id'].to_i
        name = params['name']
        score = params['score'].to_i
        record = {:name=>name, :id=>id, :score=>score}
        results.push(record)
        results.sort! do |a,b|
            b[:score] <=> a[:score]
        end
        "#{(results.index(record).to_i + 1)}"
    elsif results.select { |result| result[:id] == id} != []
        "error:id #{id} is already exist"
    else
        "error:未入力の項目があります"
    end
end

get '/ranking_id' do
    if params['id'].nil?
        return "error:idが未入力です"
    end
    id = params['id'].to_i
    results.sort! do |a,b|
        b[:score] <=> a[:score]
    end
    if results.select { |result| result[:id] == id} == []
        return "id #{id} is not exist"
    end
    "#{(results.index(results.select { |result| result[:id] == id}[0]).to_i + 1) }"
end

get '/qrtest' do

    if params['content'].nil?
        content = 'test'
    else
        content = params['content']
    end
    qr = RQRCode::QRCode.new(content)
    png = qr.to_img
    png.resize(200, 200).save("public/qr/#{content}.png")
    
end

post '/qr' do
    @name = params[:name]
    @score_VR = params[:scoreVR].to_i
    @score_2D = params[:score2D].to_i
    @total = @score_VR + @score_2D
    @player = Player.new(name: @name, scoreVR: @score_VR, score2D: @score_2D, total: @total)
    @player.save
    @url = "https://result-magiblo.herokuapp.com/result/#{player.id}"
    #@url = "localhost:4567/result/#{player.id}"
    qr = RQRCode::QRCode.new(@url, :size => 7, :level => :h)
    @png = qr.to_img
    @path = "public/qr/#{player.id}.png"
    @png.resize(200,200).save(@path)
    @path
end

get '*' do
    return "404 Not Found"
end

helpers do
    def today?(day)
        day.to_date == Date.today
    end

    def error_missing_player
        "URLが間違っているか、データが登録されていない可能性があります。"
    end
end
