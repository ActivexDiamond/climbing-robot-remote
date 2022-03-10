local middleclass = {
  _VERSION = [[
  	- middleclass  v4.1.1 
  	- MixinEdit    v1.0.0 
  	- NamingRevamp v1.0.0
  ]],
  
  _DESCRIPTION = [[
	  - Middleclass:  Object Orientation for Lua.
	  - MixinEdit:    Updates isInstanceOf and isSubclassOf to handle mixins.
	  - NamingRevamp: Revamps middleclass's naming conventions to be more uniform.
  ]],
  
  _URL = [[
  	middleclass:  https://github.com/kikito/middleclass
  	MixinEdit:    https://github.com/ActivexDiamond/cruxclass
  	NamingRevamp: https://github.com/ActivexDiamond/cruxclass
  ]],
  
  _LICENSE = [[
    MIT LICENSE
    Copyright (c) 2011 Enrique GarcÃ­a Cota
    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]],
  
  _MIXIN_EDIT_CHANGES = [[
	  Mixin Additions:
	  	Mixins can also hold fields, not only methods.
	    Added array "mixins" to all classes.
	  	"include" updates "mixins" field with references
	  		towards the newly included mixins.
	  	
	  	"isInstanceOf" checks list of mixins, plus usual operation.
	  	"isSubclassOf" checks list of mixins, plus usual operation.
  ]],
  
  _NAMING_REVAMP_CHANGES = [[	
	  Naming Conventions Changes:
	  	+ New Conventions:
	  		identifier = keywords, fundamental methods.
	  		__identifier = lua metamethods, middleclass metamethods.
			__identifier__ = middleclass internal methods/data.  		
	  	
	  	Fundemental Methods:
		  	"initialise" renamed to "init".
		  	"isInstanceOf" renamed to "instanceof".
		  	"isSubclassOf" renamed to "subclassof".
	  	
	  	Middleclass Metamethods:
		  	"allocate" renamed to "__allocate".
		  	"new" renamed to "__new".
		  	"subclassed" renamed to "__subclassed".
		  	"included" renamed to "__included".
	  	
	  	Middleclass Internal Data:
	  		"name" renamed to "__name__".
	  		"subclasses" renamed to "__subclasses__".
	  		"__mixins__" renamed to "__mixins__".
	  		
	  	Middleclass Internal Methods:
		  	"__instanceDict" renamed to "__instanceDict__".
		  	"__declaredMethods__" renamed to "__declaredMethods__".
  ]],
  
  NAMING_REVAMP_PROPOSED_CONVENTIONS = [[
	Fields: 
		private: Enforced, possible getter/setter.
		protected: Technically public, 
			but mutable fields are never accessed directly.
		public: All caps,
			Only final fields are accessed directly.
	
	Methods:
		private: Enforced.
		protected: Technically public,
			prefixed with a single underscore.
		public: "Enforced".
	
	Examples:
		local x = 666			-- private
		self.x = 42				-- protected
		self.PIE = 3.14			-- public
		
		local function getX()	-- private
		self:_getX()			-- protected
		self:getX()				-- public
		
	Note: "Technically public", as in it CAN be accessed publicly,
	 	security wise, but should never be, following convention.
  ]] 
}

local function _createIndexWrapper(aClass, f)
  if f == nil then
    return aClass.__instanceDict__
  else
    return function(self, __name__)
      local value = aClass.__instanceDict__[__name__]

      if value ~= nil then
        return value
      elseif type(f) == "function" then
        return (f(self, __name__))
      else
        return f[__name__]
      end
    end
  end
end

local function _propagateInstanceMethod(aClass, __name__, f)
  f = __name__ == "__index" and _createIndexWrapper(aClass, f) or f
  aClass.__instanceDict__[__name__] = f

  for subclass in pairs(aClass.__subclasses__) do
    if rawget(subclass.__declaredMethods__, __name__) == nil then
      _propagateInstanceMethod(subclass, __name__, f)
    end
  end
end

local function _declareInstanceMethod(aClass, __name__, f)
  aClass.__declaredMethods__[__name__] = f

  if f == nil and aClass.super then
    f = aClass.super.__instanceDict__[__name__]
  end

  _propagateInstanceMethod(aClass, __name__, f)
end

local function _tostring(self) return "class " .. self.__name__ end
local function _call(self, ...) return self:__new(...) end

local function _createClass(__name__, super)
  local dict = {}
  dict.__index = dict

  local aClass = { __name__ = __name__, super = super, static = {},
                   __instanceDict__ = dict, __declaredMethods__ = {},
                   __subclasses__ = setmetatable({}, {__mode='k'}),
                   __mixins__ = {}  }

  if super then
    setmetatable(aClass.static, {
      __index = function(_,k)
        local result = rawget(dict,k)
        if result == nil then
          return super.static[k]
        end
        return result
      end
    })
  else
    setmetatable(aClass.static, { __index = function(_,k) return rawget(dict,k) end })
  end

  setmetatable(aClass, { __index = aClass.static, __tostring = _tostring,
                         __call = _call, __newindex = _declareInstanceMethod })

  return aClass
end

local function _tableContains(t, o) 	----------
	for _, v in ipairs(t or {}) do		----------
		if v == o then return true end  ----------
	end									----------
	return false						----------
end

local function _includeMixin(aClass, mixin)
  assert(type(mixin) == 'table', "mixin must be a table")

  -- If including the DefaultMixin, then class.__mixins__
  -- will at that point still be nil.
  -- DefaultMixin is not __included in class.__mixins__
  if aClass.__mixins__ then table.insert(aClass.__mixins__, mixin) end	--------------
    
  for name,method in pairs(mixin) do
    if name ~= "__included" and name ~= "static" then aClass[name] = method end
  end

  for name,method in pairs(mixin.static or {}) do
    aClass.static[name] = method
  end

  if type(mixin.__included)=="function" then mixin:__included(aClass) end
  return aClass
end

local DefaultMixin = {
  __tostring   = function(self) return "instance of " .. tostring(self.class) end,

  init   = function(self, ...) end,

  instanceof = function(self, aClass)
    return type(aClass) == 'table'
       and type(self) == 'table'
       and (self.class == aClass	
            or type(self.class) == 'table'
            and (_tableContains(self.class.__mixins__, aClass) ----------
	            or type(self.class.subclassof) == 'function'
	            and self.class:subclassof(aClass)))
  end,

  static = {
--  	__mixins__ = setmetatable({}, {__mode = 'k'})
    __mixins__ = {}, -------------------
    
    __allocate = function(self)
      assert(type(self) == 'table', "Make sure that you are using 'Class:__allocate' instead of 'Class.__allocate'")
      return setmetatable({ class = self }, self.__instanceDict__)
    end,

    __new = function(self, ...)
      assert(type(self) == 'table', "Make sure that you are using 'Class:__new' instead of 'Class.__new'")
      local instance = self:__allocate()
      instance:init(...)
      return instance
    end,

    subclass = function(self, __name__)
      assert(type(self) == 'table', "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
      assert(type(__name__) == "string", "You must provide a __name__(string) for your class")

      local subclass = _createClass(__name__, self)

      for methodName, f in pairs(self.__instanceDict__) do
        _propagateInstanceMethod(subclass, methodName, f)
      end
      subclass.init = function(instance, ...) return self.init(instance, ...) end

      self.__subclasses__[subclass] = true
      self:__subclassed(subclass)

      return subclass
    end,

    __subclassed = function(self, other) end,

    subclassof = function(self, other)
	  return type(self) == 'table' and
	  	 	 type(other) == 'table' and
		  	 	(_tableContains(self.__mixins__, other) or
		  	 	type(self.super) == 'table' and
	  	 		(self.super == other or
	  	 		self.super:subclassof(other)))
    end,

    include = function(self, ...)
      assert(type(self) == 'table', "Make sure you that you are using 'Class:include' instead of 'Class.include'")
      for _,mixin in ipairs({...}) do _includeMixin(self, mixin) end
      return self
    end    
  }
}

function middleclass.class(__name__, super)
  assert(type(__name__) == 'string', "A __name__ (string) is needed for the __new class")
  return super and super:subclass(__name__) or _includeMixin(_createClass(__name__), DefaultMixin)
end

setmetatable(middleclass, { __call = function(_, ...) return middleclass.class(...) end })

return middleclass

--[[
Old -> New
  __tostring
  initialise		->	init
  isInstanceOf  	->	instanceof
  
  class	
  
  static {
  	allocate		->	__allocate
  	new				->	__new
  	subclass
  	subclassed		->	__subclassed
  	isSubclassOf	->	subclassof
  	include
  	
  	[mixin]included ->	__included
  					[+]	__mixins__
  	
  	name			->	__name__
  	super	
  	__instanceDict	->	__instanceDict__
  	__declaredMethods>	__declaredMethods__
  	subclasses		-	 __subclasses__
  	
----------------------------------------

  	mthd = keywords: super, class, static
  					 instanceof, subclassof
			 fundementals: init, subclass, include
		
	__mthd =  metamethods: __tostring,
			  middleclass_metamethods: __allocate,
			  	__new, __subclassed, __included
			  		
		
	__mthd__ = middleclass_internal_methods: __instanceDict__,
					__declaredMethods__
			    middleclass_internal_data: __name__,
			    	__subclasses__, __mixins__		
			 
--]]

--[[
Fields: 
	private: Enforced, possible getter/setter.
	protected: Technically public, 
		but fields are never accessed directly.
	public: Fields are never public.

Methods:
	private: Enforced.
	protected: Technically public,
		prefixed with a single underscore.
	public: "Enforced".

Examples:
	local x = 3.14			-- private
	self.x = 42				-- protected
	
	local function getX()	-- private
	self:_getX()			-- protected
	self:getX()				-- public
--]]