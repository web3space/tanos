## TEXT

### Just Text

```JSON
{
    "text": "Could be line here"
}
```

### Variable

```JSON
{
    "text": "Could be variable here {{$user.value}}"
}
```

### Few lines

```JSON
{
    "text": ["Could be", "Few lines"]
}
```

### Localized


```JSON
{
    "text": {
       "ru": "...",
       "en": "...",
       "ua": "...",
       "langVar": "$user.lang"
    }
}
```

langVar stores the name of varible where to get the current language

```Javascript

$user.lang = "en";

console.log($user.lang); //=> en

```

## BUTTONS

### Just buttons

```JSON
{
    "buttons": {
        "hello": "goto:another-step1",
        "world": "goto:another-step2"
    }
}
```

### Buttons with store

```JSON
{
    "buttons": {
        "hello": {
            "store": "$user.action = 'hello'",
            "goto": "another-step"
        }
    }
}
```

Use Livescript syntax inside `store`

Available variables: `$user`,`$global` 

### Localized buttons

No Documentation yet

## MENU

### Just menu

```JSON
{
    "menu": {
        "hello": "goto:another-step1",
        "world": "goto:another-step2"
    }
}
```

### Menu with store


```JSON
{
    "menu": {
        "hello": {
            "store": "$user.action = 'hello'",
            "goto": "another-step"
        }
    }
}
```

Use Livescript syntax inside `store`

Available variables: `$user`,`$global` 

### Localized menu

No Documentation yet



## CONDITIONS


### onText 

```JSON
{
    "onText": {
        "store": "$user.firstname = $text"
    }
}
```

Use Livescript syntax inside `store`

Available variables: `$user`,`$global`, `$text` 



### redirectCondition

```JSON
{
    "redirectCondition": {
        "($user.lang ? '').length is 2": "choose-action-step"
    }
}
```
redirectCondition condition is object where 

* keys are conditions
* values are step names



