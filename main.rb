require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader'
require 'rqrcode'
require 'rqrcode_png'


results =[
    {:name => "せんぱい", :id => 114514,:score => 810, :side => "VR"},
    {:name => "たいちん",:id => 777777,:score => 920, :side => "2D"}
]

 get '/result' do
    "idがありません。"
 end

get '/result/:id' do
    if !params['id'].nil?
        id = params['id'].to_i
        if results.select { |result| result[:id] == id } != []
            result = results.select { |result| result[:id] == id }[0]
            @score = "#{result[:score]}"
            @name = "#{result[:name]}"
            @rank = "#{results.index(results.select { |result| result[:id] == id}[0]).to_i + 1}"
            erb:result
        else
            "URLが間違っているか、データが登録されていない可能性があります。"
        end
    else
        "URLが間違っているか、データが登録されていない可能性があります。"
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
    ""
end

get '*' do
    return "404 Not Found"
end