describe NanoStore::Model do

  class User < NanoStore::Model; end

  class Plane < NanoStore::Model
    attribute   :name
    attribute   :age
    belongs_to  :user
  end

  class User < NanoStore::Model
    attribute :name
    attribute :age
    attribute :created_at
    has_many  :planes, :class => Plane, :dependent => :destroy
  end

  class Listing < NanoStore::Model
    attribute :name
  end

  def stub_user(name, age, created_at)
    user = User.new
    user.name = name
    user.age  = age
    user.created_at = created_at
    user
  end

  before do
    NanoStore.shared_store = NanoStore.store
  end

  after do
    NanoStore.shared_store = nil
  end

  it "create object" do
    user = stub_user("Bob", 10, Time.now)
    user.save

    user.info.keys.include?("name").should.be.true
    user.info.keys.include?("age").should.be.true
    user.info.keys.include?("created_at").should.be.true

    user.info["name"].should == "Bob"
    user.info["age"].should == 10
    user.info["created_at"].should == user.created_at

    user.name.should == "Bob"
    user.age.should == 10
    User.count.should == 1
  end

  it "create object with nil field" do
    user = stub_user("Bob", 10, nil)
    user.save
    user.key.should.not.be.nil
  end

  it "create object with initializer" do
    name = "Abby"
    age  = 30
    created_at = Time.now
    user = User.create(:name => name, :age => age, :created_at => created_at)
    user.name.should == name
    user.age.should == age
    user.created_at.should == created_at
  end

  it "throw error when invalid parameter on initialize" do
    lambda {
      user = User.new(:name => "Eddie", :age => 12, :created_at => Time.now, :gender => "m")
    }.should.raise(::NanoStore::NanoStoreError)
  end

  it "update objects" do
    user = stub_user("Bob", 10, Time.now)
    user.save

    user1 = User.find(:name, NSFEqualTo, "Bob").first
    user1.name = "Dom"
    user1.save

    user2 = User.find(:name, NSFEqualTo, "Dom").first
    user2.key.should == user.key
  end

  it "delete object" do
    user = stub_user("Bob", 10, Time.now)
    user.save

    users = User.find(:name, NSFEqualTo, "Bob")
    users.should.not.be.nil
    users.count.should == 1

    user.delete
    users = User.find(:name, NSFEqualTo, "Bob")
    users.should.not.be.nil
    users.count.should == 0
    User.count.should == 0
  end


  it "bulk delete" do
    user = stub_user("Bob", 10, Time.now)
    user.save

    user = stub_user("Ken", 12, Time.now)
    user.save

    user = stub_user("Kyu", 14, Time.now)
    user.save

    plane = Plane.create(:name => "A730", :age => 20)

    User.count.should == 3
    User.delete({:age => {NSFGreaterThan => 10}})
    User.count.should == 1

    User.delete({})
    User.count.should == 0
    Plane.count.should == 1
  end

  # see github issue #15
  # https://github.com/siuying/NanoStoreInMotion/issues/15
  it "should handle some class name with conflicts" do
    listing = Listing.new
    listing.name = "A"
    listing.save

    Listing.count.should == 1
    Listing.all.size.should == 1
  end

  describe "Has_many/belongs_to relationships" do
    it "test" do
      u = User.new(:name => "Flo", :age => 25)
      u.save
      u.planes.all.should == []
      Plane.create(:user_key => u.key, :name => "Concorde", :age => 40)
      u.planes.all.count.should == 1
      u.planes.first.name.should == "Concorde"
    end

    it "should 2" do
      u = User.new(:name => "Flo", :age => 25)
      u.save
      u.planes.all.should == []
      u.planes.create(:name => "Concorde", :age => 40)
      u.planes.all.count.should == 1
      u.planes.first.name.should == "Concorde"
    end

    it "should delete in cascade" do
      u1 = User.create(:name => "Flo", :age => 25)
      Plane.create(:user_key => u1.key, :name => "Concorde", :age => 40)
      Plane.count.should == 1
      u1.planes.all.count.should == 1

      u2 = User.create(:name => "Flo2", :age => 12)
      Plane.create(:user_key => u2.key, :name => "A380", :age => 4)
      Plane.count.should == 2
      u2.planes.all.count.should == 1
      u2.planes.where(:age => 4).where(:name => "A380").all.count.should == 1
      u2.planes.where(:age => 40).all.count.should == 0

      u1.delete
      User.count.should == 1
      Plane.count.should == 1

      u2.delete
      User.count.should == 0
      Plane.count.should == 0
    end

    it "should create or update records" do
      u1 = User.create(:name => "Flo", :age => 25)
      u2 = User.create_or_update({:name => "Flo"}, {:name => "Florian", :age => 42})
      User.count.should == 1
      u2.name.should == "Florian"
      u2.age.should == 42

      u2.planes.create(:name => "Concorde", :age => 12)
      u2.planes.all.count.should == 1
      u2.planes.create_or_update({:name => "Concorde"}, {:age => 40})
      u2.planes.all.count.should == 1
      u2.planes.first.name.should == "Concorde"
      u2.planes.first.age.should == 40
    end
  end

end
