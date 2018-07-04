require 'sqlite3'
require 'singleton'

class QuestionDBConnection < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class ModelBase

  def self.find_by_id(id)
      data = QuestionDBConnection.instance.execute(<<-SQL, id: id)
      SELECT
      *
      FROM
      #{@table}
      WHERE
      id = :id
      SQL

      self.new(data.first)
  end
end



class Question < ModelBase
  attr_accessor :title, :body, :user_id

  def self.all
    data = QuestionDBConnection.instance.execute("SELECT * FROM questions")
    data.map {|datum| Question.new(datum)}
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @user_id = options['user_id']
    @table = "questions"
  end


  # def self.find_by_id(id)
  #   data = QuestionDBConnection.instance.execute(<<-SQL, id)
  #   SELECT
  #   *
  #   FROM
  #   questions
  #   WHERE
  #   id = ?
  #   SQL
  #
  #   Question.new(data.first)
  # end

  def self.find_by_author_id(user_id)
    data = QuestionDBConnection.instance.execute(<<-SQL, user_id)
      SELECT * FROM questions WHERE user_id = ?
      SQL
    data.map {|datum| Question.new(datum)}
  end

  def author
    User.name(@user_id)
  end

  def replies
    Reply.find_by_question_id(@id)
  end

  def followers
    QuestionFollow.followers_for_question_id(@id)
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def likers
    QuestionLike.likers_for_question_id(@id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(@id)
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end
end

class User
  attr_accessor :fname, :lname

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def self.find_by_name(fname, lname)
    data = QuestionDBConnection.instance.execute(<<-SQL, fname, lname)
      SELECT * FROM users WHERE fname = ? AND lname = ?
      SQL
    User.new(data.first)
  end

  def self.name(id)
    data = QuestionDBConnection.instance.execute(<<-SQL, id)
      SELECT fname, lname FROM users WHERE id = ?
      SQL
    User.new(data.first)
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(@id)
  end

  def authored_questions
    Question.find_by_author_id(@id)
  end

  def authored_replies
    Reply.find_by_user_id(@id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(@id)
  end

  def average_karma
    data = QuestionDBConnection.instance.execute(<<-SQL, @id)
    SELECT CAST(count(questions_likes.question_id) AS FLOAT)/count(DISTINCT(questions.id))
    FROM questions LEFT OUTER JOIN questions_likes ON questions.id = questions_likes.question_id
    WHERE questions.id IN (SELECT questions.id FROM questions WHERE questions.user_id = ?)
    SQL

    data.first.values
  end

  def save
    if @id
      QuestionDBConnection.instance.execute(<<-SQL, @fname, @lname, @id)
      UPDATE
      users
      SET
        fname = ?, lname = ?
      WHERE
        id = ?
      SQL
    else
      QuestionDBConnection.instance.execute(<<-SQL, @fname, @lname)
      INSERT INTO
      users (fname, lname)
      VALUES
      (?,?)
      SQL
      @id = QuestionDBConnection.instance.last_insert_row_id
    end
  end
end

class Reply
  attr_accessor :user_id, :question_id, :parent_reply_id, :body

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @body = options['body']
    @user_id = options['user_id']
    @parent_reply_id = options['parent_reply_id']
  end

  def self.find_by_user_id(user_id)
    data = QuestionDBConnection.instance.execute(<<-SQL, user_id)
      SELECT * FROM replies WHERE user_id = ?
      SQL
    data.map {|datum| Reply.new(datum)}
  end

  def self.find_by_question_id(question_id)
    data = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT * FROM replies WHERE question_id = ?
      SQL
    data.map {|datum| Reply.new(datum)}
  end

  def author
    User.name(@user_id)
  end

  def question
    Question.find_by_id(@question_id)
  end

  def parent_reply
      data = QuestionDBConnection.instance.execute(<<-SQL, @parent_reply_id)
        SELECT * FROM replies WHERE id = ?
        SQL
      Reply.new(data.first)
  end

  def child_replies
    data = QuestionDBConnection.instance.execute(<<-SQL, @id)
      SELECT * FROM replies WHERE parent_reply_id = ?
      SQL
    data.map { |datum| Reply.new(datum) }
  end

end

class QuestionFollow
  attr_accessor :user_id, :question_id

  def initialize(options)
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def self.followers_for_question_id(question_id)
    data = QuestionDBConnection.instance.execute(<<-SQL, question_id)
    SELECT
      users.id, users.fname, users.lname
    FROM
    users
    JOIN
    questions_follows ON questions_follows.user_id = users.id
    WHERE questions_follows.question_id = ?
    SQL

    data.map{|datum| User.new(datum)}
  end

  def self.followed_questions_for_user_id(user_id)
    data = QuestionDBConnection.instance.execute(<<-SQL, user_id)
    SELECT
    questions.id, questions.title , questions.body, questions.user_id
    FROM
    questions
    JOIN
    questions_follows ON questions_follows.question_id = questions.id
    WHERE questions_follows.user_id = ?
    SQL

    data.map{|datum| Question.new(datum)}
  end

  def self.most_followed_questions(n)
    data = QuestionDBConnection.instance.execute(<<-SQL, n)
    SELECT questions.id, questions.title , questions.body, questions.user_id
    FROM questions
    JOIN questions_follows ON questions_follows.question_id = questions.id
    GROUP BY questions_follows.question_id
    HAVING count(questions_follows.user_id)
    ORDER BY count(questions_follows.user_id) DESC LIMIT ?
    SQL

    data.map{|datum| Question.new(datum)}
  end
end

class QuestionLike
  attr_accessor :user_id, :question_id

  def initialize(options)
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def self.likers_for_question_id(question_id)
    data = QuestionDBConnection.instance.execute(<<-SQL, question_id)
    SELECT
      users.id, users.fname, users.lname
    FROM
    users
    JOIN
    questions_likes ON questions_likes.user_id = users.id
    WHERE questions_likes.question_id = ?
    SQL

    data.map{|datum| User.new(datum)}
  end

  def self.num_likes_for_question_id(question_id)
    data = QuestionDBConnection.instance.execute(<<-SQL, question_id)
    SELECT COUNT(questions_likes.user_id)
    FROM questions_likes
    WHERE question_id = ?
    SQL
    #[{"COUNT)" => 2}]
    data.first.values.first
  end

  def self.liked_questions_for_user_id(user_id)
    data = QuestionDBConnection.instance.execute(<<-SQL, user_id)
    SELECT questions.id, questions.title , questions.body, questions.user_id
    FROM questions
    JOIN questions_likes ON questions_likes.question_id = questions.id
    WHERE questions_likes.user_id = ?
    SQL

    data.map{|datum| Question.new(datum)}
  end

  def self.most_liked_questions(n)
    data = QuestionDBConnection.instance.execute(<<-SQL, n)
    SELECT questions.id, questions.title , questions.body, questions.user_id
    FROM questions
    JOIN questions_likes ON questions_likes.question_id = questions.id
    GROUP BY questions_likes.question_id
    HAVING count(questions_likes.user_id)
    ORDER BY count(questions_likes.user_id) DESC LIMIT ?
    SQL

    data.map{|datum| Question.new(datum)}
  end


end

if __FILE__ == $PROGRAM_NAME
p a = User.find_by_name("Garbo","Cheng")
p a.average_karma
end
