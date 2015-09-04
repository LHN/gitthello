module Gitthello
  class GithubHelper
    attr_reader :issue_bucket, :backlog_bucket

    def initialize(oauth_token, repos_to, repos_from)
      @github            = Github.new(:oauth_token => oauth_token)
      @user, @repo       = repos_to.split(/\//)
      @repos_from        = repos_from
    end

    def create_issue(title, desc)
      @github.issues.
        create( :user => @user, :repo => @repo, :title => title, :body => desc)
    end

    def issue_closed?(user, repo, number)
      get_issue(user,repo,number).state == "closed"
    end

    def close_issue(user, repo, number)
      @github.issues.edit(user, repo, number.to_i, :state => "closed")
    end

    def get_issue(user, repo, number)
      return if number.to_i == 0
      @github.issues.get(user, repo, number.to_i)
    end

    def get_comments(user, repo, number)
      @github.issues.comments.list(user: user, repo: repo, number: number)
    end

    def add_trello_url(issue, url)
      owner, repo, number = repo_owner(issue), repo_name(issue), issue.number
      description = get_issue(owner,repo,number).body.body || ""

      unless description =~ /\[Trello Card\]/ or
          description =~ /\[Added by trello\]/
        repeatthis do
          @github.issues.
            edit(owner, repo, number.to_i,
                 :body => description + "\n\n\n[Trello Card](#{url})")
        end
      end
    end

    def retrieve_issues
      @issue_bucket, @backlog_bucket = [], []

      @repos_to.split(/,/).map { |a| a.split(/\//)}.
        each do |repo_owner,repo_name|
        puts "Checking #{repo_owner}/#{repo_name}"
        repeatthis do
          @github.issues.
            list(:user => repo_owner, :repo => repo_name, :state => "open",
                 :per_page => 100).
            sort_by { |a| a.number.to_i }
        end.each do |issue|
          (if issue["labels"].any? { |a| a["name"] == "backlog" }
             @backlog_bucket
           else
             @issue_bucket
           end) << [repo_name,issue]
        end
      end

      puts "Found #{@issue_bucket.count} todos"
      puts "Found #{@backlog_bucket.count} backlog"
    end

    def new_issues_to_trello(trello_helper)
      issue_bucket.each do |repo_name, issue|
        next if trello_helper.has_card?(issue)
        prefix = repo_name.sub(/^mops./,'').capitalize
        card = trello_helper.
          create_todo_card("%s: %s" % [prefix,issue["title"]],
                           issue["body"], issue["html_url"],
                           issue.labels.map(&:name),
                           issue.assignee.try(:login))
        add_trello_url(issue, card.url)
      end

      backlog_bucket.each do |repo_name, issue|
        next if trello_helper.has_card?(issue)
        prefix = repo_name.sub(/^mops./,'').capitalize
        card = trello_helper.
          create_backlog_card("%s: %s" % [prefix,issue["title"]],
                              issue["body"], issue["html_url"],
                              issue.labels.map(&:name),
                              issue.assignee.try(:login))
        add_trello_url(issue, card.url)
      end
    end

    private

    def repo_owner(issue)
      # assumes the that the url is something like:
      #   https://api.github.com/repos/<repo_owner>/<repo_name>/issues/<number>
      issue["url"].split("/")[-4]
    end

    def repo_name(issue)
      # assumes the that the url is something like:
      #   https://api.github.com/repos/<repo_owner>/<repo_name>/issues/<number>
      issue["url"].split("/")[-3]
    end

    def repeatthis(cnt=5,&block)
      last_exception = nil
      cnt.times do
        begin
          return yield
        rescue Exception => e
          last_exception = e
          sleep 0.1
          next
        end
      end
      raise last_exception
    end
  end
end
