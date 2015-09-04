module Gitthello
  class Board
    attr_reader :trello_helper, :github_helper

    def initialize(board_config)
      @config = board_config.clone
      @list_map = {
        todo: @config.marshal_dump.fetch(:todo_list_name, 'To Do'),
        backlog: @config.marshal_dump.fetch(:backlog_list_name, 'Backlog'),
        done: @config.marshal_dump.fetch(:done_list_name, 'Done')
      }
      @github_helper = GithubHelper.new(Gitthello.configuration.github.token,
                                        @config.repo_for_new_cards,
                                        @config.repos_to_consider)
      @trello_helper = TrelloHelper.new(Gitthello.configuration.trello.token,
                                        Gitthello.configuration.trello.dev_key,
                                        @config.name,
                                        self,
                                        @list_map)
    end

    def synchronize
      puts "==> Handling Board: #{@config.name}"
      @trello_helper.setup
      @trello_helper.close_issues(@github_helper)
      @trello_helper.move_cards_with_closed_issue(@github_helper)
      @github_helper.retrieve_issues
      @github_helper.new_issues_to_trello(@trello_helper)
      @trello_helper.new_cards_to_github(@github_helper)
    end

    def add_trello_link_to_issues
      @trello_helper.setup
      @trello_helper.add_trello_link_to_issues(@github_helper)
    end

    def name
      @config.name
    end

    def color_for_label(label)
      @colors.each_pair.to_a.select {|p| p[1] === label}.flatten[0]
    end
  end
end
