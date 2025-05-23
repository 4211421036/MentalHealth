-module(security_monitor).
-export([start/0, log_event/2, slack_alert/1]).

start() ->
    spawn(fun() -> 
        ets:new(security_events, [ordered_set, public, named_table]),
        monitor_loop()
    end).

log_event(Type, Details) ->
    Timestamp = os:system_time(millisecond),
    ets:insert(security_events, {Timestamp, Type, Details}).

%% Implementasi fungsi slack_alert/1 yang sebelumnya missing
slack_alert(Message) ->
    WebhookUrl = os:getenv("SLACK_WEBHOOK_URL"),
    case WebhookUrl of
        false ->
            io:format("[SLACK] Alert suppressed (no webhook): ~s~n", [Message]);
        _ ->
            Body = io_lib:format("{\"text\":\"Security Alert: ~s\"}", [Message]),
            httpc:request(post, 
                {WebhookUrl, [], "application/json", Body},
                [],
                [])
    end.

monitor_loop() ->
    receive
        {analyze, From} ->
            Suspicious = ets:match_object(security_events, {'_', brute_force, '_'}),
            From ! {analysis, length(Suspicious)},
            monitor_loop()
    after 5000 ->
        case ets:info(security_events, size) > 100 of
            true -> slack_alert("High activity detected!");
            false -> ok
        end,
        monitor_loop()
    end.
