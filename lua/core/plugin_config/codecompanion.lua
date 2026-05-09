require("codecompanion").setup({
  adapters = {
    ollama = function()
      return require("codecompanion.adapters").extend("ollama", {
        env = {
          url = "http://127.0.0.1:11434",
        },
        schema = {
          model = {
            default = "qwen2.5-coder:7b",
          },
        },
      })
    end,
  },

  strategies = {
    chat = {
      adapter = "ollama",
    },
    inline = {
      adapter = "ollama",
    },
  },
})
