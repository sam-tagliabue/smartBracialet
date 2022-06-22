/**
 *  Source file for implementation of module sendAckC in which
 *  the node 1 send a request to node 2 until it receives a response.
 *  The reply message contains a reading from the Fake Sensor.
 *
 *  @author Luca Pietro Borsani
 */

#include "smartBracelet.h"
#include "Timer.h"

module smartBraceletC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	interface AMSend;
	interface Receive;
	interface SplitControl;
	interface Packet;
	interface PacketAcknowledgements;
	interface Leds;
	interface Timer<TMilli> as timerPairing;
	interface Timer<TMilli> as timer10s;
    interface Timer<TMilli> as timer60s;
    
    
	interface Read<uint16_t> as Fakesensor;

  }

} implementation {

  uint8_t KeyP[20];
  uint8_t KeyC[20];
  message_t packet;
  bool locked=FALSE;
  bool isParent=FALSE;
  

  event void Boot.booted() {
	dbg("boot","Application booted.\n");
	call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
        if (err == SUCCESS) {
      dbg("radio","Device Ready!\n");
      dgg ("Pairing", "Pairing phase started \n");
      call MilliTimer.startPeriodic(1000);
    }
    else {
      dbgerror("radio", "[error]Radio starting error\n");
      call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err){
   
  }

  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
  	/* This event is triggered every time the timer fires.
	 * When the timer fires, we send a request
	 * Fill this part...
	 */
  
  	counter++;
    dbg("timer", "Timer fired, counter is %hu.\n", counter);
    
    if (locked) {
      return;
    }
    else {
    sendReq();
    }
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
	/* This event is triggered when a message is sent 
	 *
	 * STEPS:
	 * 1. Check if the packet is sent
	 * 2. Check if the ACK is received (read the docs)
	 * 2a. If yes, stop the timer according to your id. The program is done
	 * 2b. Otherwise, send again the request
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	     if (&packet == buf) {
      locked = FALSE;
      dbg("radio_send", "Packet sent...");
      dbg_clear("radio_send", " at time %s \n", sim_time_string());
    }
    if (call PacketAcknowledgements.wasAcked(buf)){
    last_digit--;
    dbg("radio_ack", "ACK received \n");
    if (last_digit==0 && TOS_NODE_ID==1){
    dbg("timer", "Timer stop\n");
    call MilliTimer.stop();
    }
    }else{
    dbg("radio_ack", "ACK not received \n");
    }
  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	/* This event is triggered when a message is received 
	 *
	 * STEPS:
	 * 1. Read the content of the message
	 * 2. Check if the type is request (REQ)
	 * 3. If a request is received, send the response
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	     if (len != sizeof(my_msg_t)) {return buf;}
    else {
      my_msg_t* rec = (my_msg_t*)payload;
      if (rec->msgType==REQ){
      
      dbg("radio_rec", "Received packet at time %s\n", sim_time_string());
      
      dbg_clear("radio_pack","\t\t Payload \n" );
      dbg_clear("radio_pack", "\t\t msg_counter: %hhu \n", rec->counter);
      dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", rec->msgType);
      counter=rec->counter;
      sendResp();
      
      }
      

  }
  }
  
  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {
	/* This event is triggered when the fake sensor finishes to read (after a Read.read()) 
	 *
	 * STEPS:
	 * 1. Prepare the response (RESP)
	 * 2. Send back (with a unicast message) the response
	 * X. Use debug statement showing what's happening (i.e. message fields)
	 */
	 	  my_msg_t* res = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
      if (res == NULL) {
		return;
      }
            res->counter = counter;
            res->msgType= RESP;
            res->value=data;
            call PacketAcknowledgements.requestAck(&packet);
      if (call AMSend.send(1, &packet, sizeof(my_msg_t)) == SUCCESS) {
		dbg("radio_send", "Sending packet:");
		dbg_clear("radio_send", " at time %s \n", sim_time_string());
		dbg_clear("radio_pack","\t\t Payload \n" );
      	dbg_clear("radio_pack", "\t\t msg_counter: %hhu \n", res->counter);
      	dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", res->msgType);
      	dbg_clear("radio_pack", "\t\t msg_value: %hhu \n", res->value);	
		locked = TRUE;
      }

}
}

