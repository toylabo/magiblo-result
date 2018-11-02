# coding: UTF-8
require 'RMagick'

def makeTweetLink(id,name,totalScore)
    tweetStr = "#{name}のスコアは【#{totalScore}】！%0a"
    tweetUrl = "https://result-magiblo.herokuapp.com/result/#{id}"
    insideAnchor = "<img src=\"../img/tweet.svg\" alt=\"結果をツイートする\">"
    return "<a href=\"https://twitter.com/intent/tweet?text=#{tweetStr}&url=#{tweetUrl}&hashtags=マジブロ,toy_labo&related=toy_labo\" onClick=\"window.open(encodeURI(decodeURI(this.href)), 'tweetwindow', 'width=650, height=470, personalbar=0, toolbar=0, scrollbars=1, sizable=1'); return false;\" rel=\"nofollow\" class=\"twitter-link\">#{insideAnchor}</a>"        
end

def makeOGPMeta (id,name,total)
    "<meta property=\"og:title\" content=\"#{name}さんのマジブロリザルト\" />
    <meta property=\"og:url\" content=\"http://result-magiblo.herokuapp.com/result/#{id}\" />
    <meta property=\"og:image\" content=\"http://result-magiblo.herokuapp.com/#{id}.png\" />
    <meta property=\"og:site_name\" content=\"マジックブロック\" />
    <meta property=\"og:description\" content=\"#{name}さんの結果です！ #{total}点取りました！!\" />
    <meta name=\"twitter:image:src\" content=\"http://result-magiblo.herokuapp.com/#{id}.png\">"
end

def makeOGP(id,name,scoreVR,score2D,isWinVR,isWin2D,charaVR,chara2D,messageVR,message2D,allPlayerRank,todayRank,restlessStr,effortStr)
    framePath = "public/img/Frame.png"
    charaVRImgPath = "public/img/#{charaVR}.png"
    chara2DImgPath = "public/img/#{chara2D}.png"

    if(isWinVR)
        resultVR = "win"
    else
        resultVR = "lose"
    end
    if(isWin2D)
        result2D = "win"
    else
        result2D = "lose"
    end

    output = "./public/#{id.to_s}.png"
    frame = Magick::ImageList.new(framePath)
    charaVRImg = Magick::ImageList.new(charaVRImgPath)
    chara2DImg = Magick::ImageList.new(chara2DImgPath)
    
    font = "./fonts/rounded-mplus-1c-medium.ttf"

    draw = Magick::Draw.new
    draw.annotate(frame,0,0,70,30, name) do
        self.font = font
        self.fill = 'white'
        self.stroke = 'transparent'
        self.pointsize = 40
        self.gravity = Magick::NorthWestGravity
    end
    draw.annotate(frame,0,0,360,55,'さんのゲーム結果') do
        self.pointsize = 25
    end
    draw.annotate(frame,0,0,65,113,'VR') do
        self.pointsize = 40
    end
    draw.annotate(frame,0,0,560,110,'2D') do
        self.pointsize = 40
    end
    draw.annotate(frame,0,0,20,310,'総合結果') do
        self.pointsize = 35
    end
    draw.annotate(frame,0,0,173,166,"Score #{scoreVR}\n結果 #{resultVR}\nメッセージ\n   #{messageVR}") do
        self.pointsize = 20
    end
    draw.annotate(frame,0,0,673,166,"Score #{score2D}\n結果 #{result2D}\nメッセージ\n   #{message2D}") do
        self.pointsize = 20
    end
    draw.annotate(frame,0,0,173,320,"Score #{scoreVR + score2D}\n当日ランキング  #{todayRank}位\n鳳祭内ランキング  #{allPlayerRank}位\n\n落ち着きの無さ  #{restlessStr}\n頑張り度    #{effortStr}") do
        self.pointsize = 18
    end

    imageWithVR = frame.composite(charaVRImg.resize_to_fit(170, 170),15,160, Magick::OverCompositeOp)
    imageWith2D = imageWithVR.composite(chara2DImg.resize_to_fit(170, 170),520,160,Magick::OverCompositeOp);

    imageWith2D.write(output)
end
