/**
 *  Configuration file for wiring of sendAckC module to other common 
 *  components needed for proper functioning
 *
 *  @author Luca Pietro Borsani
 */

#include "smartBracelet.h"

configuration smartBraceletAppC {}

implementation {


/****** COMPONENTS *****/
  components MainC, smartBraceletC as App;
  components new AMSenderC(AM_RADIO_TYPE);
  components new AMReceiverC(AM_RADIO_TYPE);
  components new TimerMilliC() as timerPairing;
  components new TimerMilliC() as timer10s;
  components new TimerMilliC() as timer60s;
  components new FakeSensorC();

/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;

  /****** Wire the other interfaces down here *****/
  //Send and Receive interfaces
  //Radio Control
  //Interfaces to access package fields
  //Timer interface
  //Fake Sensor read
  App.Boot -> MainC.Boot;
  
  // Radio interface
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  App.AMControl -> RadioAM;
  
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.PacketAcknowledgements -> RadioAM;

  // Timers
  App.timerPairing -> timerPairing;
  App.timer10s -> timer10s;
  App.timer60s -> timer60s;
  

  App.FakeSensor -> FakeSensorC;

}

