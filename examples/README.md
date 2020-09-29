# Potato Example

This is an example application based on Potato.

## Running the application

To run the application you will need two REPLs. Start them as follows.

```
iex --sname bob --cookie "secret" -S mix 

iex --sname alice --cookie "secret" -S mix
```

Then you should start one as the "phone" and one as the "temperature" sensor.

```
Potato.Temperature.run()
```

and in the other REPL

```
Potato.Phone.run() 
```

This will start the applications.


