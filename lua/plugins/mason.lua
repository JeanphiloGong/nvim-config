-- ~/.confing/nvim/lua/plugins/mason.lua
return {                                                                                             
    "williamboman/mason.nvim",                                                                  
    build = ":MasonUpdate",                                                                     
    config = function()                                                                         
      require("mason").setup()                                                                  
    end,                                                                                        
  }
