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

  uint8_t key[20];
  sb_msg_t packet;
  bool locked=FALSE;
  bool busy=FALSE;
  bool isParent=FALSE;
  uint16_t counter = 0;
  am_addr_t address_coupled_device;
  
    void send_confirmation();
  void send_info_message();
  

  event void Boot.booted() {
	dbg("boot","Application booted.\n");
	if(TOS_NODE_ID%2==0){
	strcpy(key,RANDOM_KEY[TOS_NODE_ID/2]);	
	isParent=TRUE;
	}else
	strcpy(key,RANDOM_KEY[TOS_NODE_ID/2]);
	call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
        if (err == SUCCESS) {
      dbg("radio","Device Ready!\n");
      dbg ("Pairing", "Pairing phase started \n");     
	call timerPairing.startPeriodic(1000);}
    else {
      dbgerror("radio", "[error]Radio starting error\n");
      call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err){
   
  }
  
    event void timerPairing.fired() {
    counter++;
    dbg("TimerPairing", "TimerPairing: timer fired at time %s\n", sim_time_string());
    if (!locked) {
      sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
      
      // Fill payload
      sb_pairing_message->msg_type = 1; // 1 for pairing phase
      sb_pairing_message->msg_id = counter;

      strcpy(sb_pairing_message->data, key);
      
      if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(sb_msg_t)) == SUCCESS) {
	      dbg("Radio", "Radio: sending pairing packet, key=%s\n", RANDOM_KEY[TOS_NODE_ID/2]);	
      }
    }
  }
  
    event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    sb_msg_t* mess = (sb_msg_t*)payload;
    // Print data of the received packet
	  dbg("Radio_rec","Message received from node %hhu at time %s\n", call AMPacket.source( bufPtr ), sim_time_string());
	  dbg("Radio_pack","Payload: type: %hu, msg_id: %hhu, data: %s\n", mess->msg_type, mess->msg_id, mess->data);
    
    if (call AMPacket.destination( bufPtr ) == AM_BROADCAST_ADDR && phase == 1 && strcmp(mess->data, key) == 0){
      // controlla che sia un broadcast e che siamo nella fase di pairing phase == 0
      // e che la chiave corrisponda a quella di questo dispositivo
      
      address_coupled_device = call AMPacket.source( bufPtr );
      dbg("Radio_pack","Message for pairing phase 1 received. Address: %hhu\n", address_coupled_device);
      send_confirmation();
      call timerPairing.stop();
      busy=TRUE;
	if (isParent)
      {call timer60s.startPeriodic(60000);}
      else
      {call timer10s.startPeriodic(10000);}
    
    } else if (phase == 1 && strcmp(mess->data, key) == 0) {
      // Enters if the packet is for this destination and if the msg_type == 1
      address_coupled_device = call AMPacket.source( bufPtr );      
      dbg("Radio_pack","Message for pairing phase 1 received\n");
      busy=TRUE;
      call TimerPairing.stop();
      	if (isParent)
      {call timer60s.startPeriodic(60000);}
      else
      {call timer10s.startPeriodic(10000);}}
      else if (call AMPacket.source( bufPtr ) == address_coupled_device && mess->msg_type == 2) {
      // Enters if the packet is for this destination and if msg_type == 2
      dbg("Radio_pack","INFO message received\n");
      dbg("Info", "Position X: %hhu, Y: %hhu\n", mess->X, mess->Y);
      dbg("Info", "Sensor status: %s\n", mess->data);
      last_status.X = mess->X;
      last_status.Y = mess->Y;
      call timer60s.stop();
      call timer60s.startOneShot(60000);
      
      // check if FALLING
      if (strcmp(mess->data, "FALLING") == 0){
        dbg("Info", "ALERT: FALLING!\n");
 	//send to serial here
      }
    }
        return bufPtr;
  }
  
    void send_confirmation(){
    counter++;
    if (!locked) {
      sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
      
      // Fill payload
      sb_pairing_message->msg_type = 1; // 1 for confirmation of pairing phase
      sb_pairing_message->msg_id = counter;
      
      strcpy(sb_pairing_message->data, key]);
      
      // Require ack
      call PacketAcknowledgements.requestAck( &packet );
      
      if (call AMSend.send(address_coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
        dbg("Radio", "Radio: sanding pairing confirmation to node %hhu\n", address_coupled_device);	
      }
    }
  }
  
    // Timer10s fired
  event void timer10s.fired() {
    dbg("Timer10s", "Timer10s: timer fired at time %s\n", sim_time_string());
    //call PositionSensor.read();
    call FakeSensor.read();
  }
  
    event void FakeSensor.readDone(error_t result, sensor_status status_local) {
	send_info_message();
  }
  
    event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr && error == SUCCESS) {
      dbg("Radio_sent", "Packet sent\n");
      busy = FALSE;
      
      if (phase == 1 && call PacketAcknowledgements.wasAcked(bufPtr) ){
        // Phase == 1 and ack received
        phase = 2; // Pairing phase 1 completed
        dbg("Radio_ack", "Pairing ack received at time %s\n", sim_time_string());
        dbg("Pairing","Pairing phase 1 completed for node: %hhu\n\n", address_coupled_device);
        
        // Start operational phase
        if (TOS_NODE_ID % 2 == 0){
          // Parent bracelet
          dbg("OperationalMode","Parent bracelet\n");
          //call SerialControl.start();
          call Timer60s.startOneShot(60000);
        } else {
          // Child bracelet
          dbg("OperationalMode","Child bracelet\n");
          call Timer10s.startPeriodic(10000);
        }
      
      } else if (phase == 1){
        // Phase == 1 but ack not received
        dbg("Radio_ack", "Pairing ack not received at time %s\n", sim_time_string());
        send_confirmation(); // Send confirmation again
      
      } else if (phase == 2 && call PacketAcknowledgements.wasAcked(bufPtr)){
        // Phase == 2 and ack received
        dbg("Radio_ack", "INFO ack received at time %s\n", sim_time_string());
        attempt = 0;
        
      } else if (phase == 2){
        // Phase == 2 and ack not received
        dbg("Radio_ack", "INFO ack not received at time %s\n", sim_time_string());
        send_info_message();
      }
        
    }
  }
  
    void send_info_message(){
    
      counter++;
      if (!locked) {
        sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
        
        // Fill payload
        sb_pairing_message->msg_type = 2; // 2 for INFO packet
        sb_pairing_message->msg_id = counter;
        
        sb_pairing_message->X = status.X;
        sb_pairing_message->Y = status.Y;
        strcpy(sb_pairing_message->data, status.status);
        
        // Require ack
        call PacketAcknowledgements.requestAck( &packet );
        
        if (call AMSend.send(address_coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
          dbg("Radio", "Radio: sanding INFO packet to node %hhu, attempt: %d\n", address_coupled_device, attempt);	
        }
      }
 
  }
  
    event void timer60s.fired() {
    dbg("Timer60s", "Timer60s: timer fired at time %s\n", sim_time_string());
    dbg("Info", "ALERT: MISSING");
    dbg("Info","Last known location: %hhu, Y: %hhu\n", last_status.X, last_status.Y);

    //send to serial here

  }
  }



