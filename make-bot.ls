require! {
  \telegram-bot-api : telegram
}

module.exports = (telegram-token)-> 
    new telegram do
        token: telegram-token
        updates:
            enabled: yes