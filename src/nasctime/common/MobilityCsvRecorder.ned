package nasctime.common;

// Periodically records the position and speed of a possibly dynamic node.
simple MobilityCsvRecorder
{
    parameters:
        string nodePath;
        string outputFile = default("mobility.csv");
        double sampleInterval @unit(s) = default(100ms);
        double startTime @unit(s) = default(0s);
        @class(nasctime::MobilityCsvRecorder);
        @display("i=block/table");
}
