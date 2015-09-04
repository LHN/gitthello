require 'ostruct'

module Gitthello
  class Configuration
    attr_reader :boards, :trello, :github, :colors, :users

    def initialize
      @trello = OpenStruct.new(:dev_key => ENV['TRELLO_DEV_KEY'],
                               :token => ENV['TRELLO_MEMBER_TOKEN'])
      @github = OpenStruct.new(:token => ENV['GITHUB_ACCESS_TOKEN'])
      # select BOARDS.XXX.YYY from the environment and map them to hashes
      # i.e. @boards becomes '{ xxx => { yyy => val } }'
      @boards = Hash.new{|h,k|h[k]={}}
      boardenv = ENV.keys.select { |k| k =~ /^BOARDS/ }
      boardenv.each do |k|
        h = k.split('.').drop(1)
        @boards[h[0].downcase][h[1].downcase] = ENV[k]
      end
      @boards = Hash[@boards.map { |k,v| [k, OpenStruct.new(v)]}]
    end
  end
end
