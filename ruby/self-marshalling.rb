# -*- coding: utf-8 -*-
#
# Issues with getting a complex Ruby object to marshal itself.
#
#   Copyright © 2011 Ken Coar
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
#================================================================
#
# I had a scenario in which the realtime object instance relationships
# mirrored the class relationships.  Let me explain.. no, there is too
# much.  Let me sum up:
#
# I have a Foo superclass, and a Foo::Bar subclass of it.  I have one
# or more Foo objects, and each has a number of Foo::Bar objects that
# are its 'children.'  The Foo class has instance variables @parent
# and @children.  For the Foo object, @parent points to itself, and
# @children is an array of Foo::Bar objects.  For each Foo::Bar
# object, @parent points back to the, erm, parent Foo object, and
# @children is unused.  Foo objects also have a @logger instance
# variable that the children leave nil.
#
# This rather complex structure, once built, needs to be
# reinstantiated in toto at need -- so the obvious solution is to
# marshal it to a file for subsequent reloading.  Since the Foo object
# has a logger, though, Marshal#dump complains about it being an IO --
# so marshalling needs to be assisted with #marshal_dump and
# #marshal_load methods that will get the logger out of the way.  This
# ends up having the object essentially marshal itself.
#
# Now, as to doing it..
#
# The first solution looked like this:
#
#     def marshal_dump
#       saved_logger = @logger
#       @logger = nil
#       results = Marshal.dump(self)
#       @logger = saved_logger
#       return results
#     end
#
# That doesn't work, though, apparently because of the #marshal_dump
# method in the object being marshalled.  What gets dumped is a virgin
# Foo object, with all of the relationships and children absent.
#
# After playing around, I confirmed that hypothesis and worked around
# it by temporarily moving the #marshal_dump method 'out of the way.'
# The working solution looks like this:
#
  def marshal_dump(*args)
    saved_logger = @logger
    @logger = nil
    #
    # Save the marshalling method in an alias and then delete it so
    # there are no recursion worries.
    #
    self.class.send(:alias_method, :marshal_dump_foo, :marshal_dump)
    self.class.send(:remove_method, :marshal_dump)
    #
    # Now we should get a *real* marshalling of us and all of our bits,
    # friends, and relations.
    #
    marshalled = Marshal.dump(self)
    @logger = saved_logger || create_logger
    #
    # Put the original #marshal_dump (that's us!) back so we are as
    # we were before.
    #
    self.class.send(:alias_method, :marshal_dump, :marshal_dump_foo)
    self.class.send(:remove_method, :marshal_dump_foo)
    #
    # Now that we're ourselves (ourself?) again, *now* return the
    # result of dumping me/us.
    #
    return marshalled
  end
#
# The result is a full dump of the parent and all the children, as desired.
#
# Next comes the reloading from the dump.  Again, this is implemented
# as the Foo object essentially loading *itself* from the dump, rather
# than creating a new fully-fleshed Foo object and returning it.  The
# working #marshal_load method looks like this:
#
  def marshal_load(map_p)
    #
    # If we get a string, it's marshalled data.  Otherwise it's something
    # that Marshal#load has already frobbed.  Load it it we have to.
    #
    map = map_p.kind_of?(String) ? Marshal.load(map_p) : map_p
    #
    # For each instance variable in the newly-created Foo
    # object, copy it into ourself.
    #
    map.instance_variables.each do |ivar|
      self.instance_variable_set(ivar.to_sym,
                                 map.instance_variable_get(ivar.to_sym))
    end
    #
    # Make sure we point to ourself as the parent of this branch of
    # the Foo family.
    #
    @parent = self
    #
    # Make sure that all the restored children point to us, as well, rather
    # than the restored Foo object.
    #
    @children.each { |o| o.parent = self }
    create_logger
    return self
  end
#
# There are two bits of extra work in there:
#
# 1. Since the logger was lost during the dump, we create a new logger
#    using the same mechanism as when the original object was
#    instantiated.
# 2. Because we want to load the marshalled data into *ourself*, and
#    the Marshal#load method returns a completely new Foo object
#    structure, we take the following steps to make its knowledge part
#    of us:
#    a) Set all of our instance variables to the same values as in the
#       dumped-and-reconstituted object;
#    b) Go through all the reconstituted children and change their
#       @parent to point to *us* rather than the reconstituted Foo
#       object.
#
# A bit funky, but not exactly expected behaviour -- hence this snippet.
#
# Enjoy!
#
