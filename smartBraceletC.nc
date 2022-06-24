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

  uint8_t Key[20];
  sb_msg_t packet;
  bool locked=FALSE;
  bool busy=FALSE;
  bool isParent=FALSE;
   am_addr_t address_coupled_device;
  

  event void Boot.booted() {
	dbg("boot","Application booted.\n");
	if(TOS_NODE_ID%2==0){
	strcpy(key,RANDOM_KEY[TOS_NODE_ID-1]);	
	isParent=TRUE;
	}else
	strcpy(key,RANDOM_KEY[TOS_NODE_ID]);
	call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
        if (err == SUCCESS) {
      dbg("radio","Device Ready!\n");
      dgg ("Pairing", "Pairing phase started \n");
	if(isParent==FALSE)      
	call timerPairing.startPeriodic(1000);
    }
    else {
      dbgerror("radio", "[error]Radio starting error\n");
      call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err){
   
  }
  
    event void TimerPairing.fired() {
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
	      busy = TRUE;
      }
    }
  }
  
    event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    sb_msg_t* mess = (sb_msg_t*)payload;
    // Print data of the received packet
	  dbg("Radio_rec","Message received from node %hhu at time %s\n", call AMPacket.source( bufPtr ), sim_time_string());
	  dbg("Radio_pack","Payload: type: %hu, msg_id: %hhu, data: %s\n", mess->msg_type, mess->msg_id, mess->data);
    
    if (call AMPacket.destination( bufPtr ) == AM_BROADCAST_ADDR && phase == 0 && strcmp(mess->data, key) == 0){
      // controlla che sia un broadcast e che siamo nella fase di pairing phase == 0
      // e che la chiave corrisponda a quella di questo dispositivo
      
      address_coupled_device = call AMPacket.source( bufPtr );
      dbg("Radio_pack","Message for pairing phase 0 received. Address: %hhu\n", address_coupled_device);
      send_confirmation();
      call Timer60s.startperiodic(60000);
    
    } else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && mess->msg_type == 0) {
      // Enters if the packet is for this destination and if the msg_type == 1
      dbg("Radio_pack","Message for pairing phase 1 received\n");
      busy=TRUE;
      call TimerPairing.stop();
      call Timer10s.startPeriodic(10000);}
      else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && mess->msg_type == 2) {
      // Enters if the packet is for this destination and if msg_type == 2
      dbg("Radio_pack","INFO message received\n");
      dbg("Info", "Position X: %hhu, Y: %hhu\n", mess->X, mess->Y);
      dbg("Info", "Sensor status: %s\n", mess->data);
      last_status.X = mess->X;
      last_status.Y = mess->Y;
      call Timer60s.startOneShot(60000);
      
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
        busy = TRUE;
      }
    }
  }
  
    // Timer10s fired
  event void Timer10s.fired() {
    dbg("Timer10s", "Timer10s: timer fired at time %s\n", sim_time_string());
    //call PositionSensor.read();
    call FakeSensor.read();
  }
  
    event void FakeSensor.readDone(error_t result, sensor_status status_local) {
    status = status_local;
    dbg("Sensors", "Sensor status: %s\n", status.status);
    // Controlla che entrambe le letture siano state fatte
    if (sensors_read_completed == FALSE){
      
      sensors_read_completed = TRUE;
    } else {
      sensors_read_completed = FALSE;
      send_info_message();
    }

	dbg("Sensors", "Position X: %hhu, Y: %hhu\n", status_local.X, status_local.Y);
    // Controlla che entrambe le letture siano state fatte
    if (sensors_read_completed == FALSE){
      // Solo una lettura è stata fatta
      sensors_read_completed = TRUE;
    } else {
      // Entrambe le letture sono state fatte quindi possiamo inviare l'INFO packet
      sensors_read_completed = FALSE;
      send_info_message();
    }
  }
  
    void send_info_message(){
    
 
    if (attempt < 3){
      counter++;
      if (!busy) {
        sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
        
        // Fill payload
        sb_pairing_message->msg_type = 2; // 2 for INFO packet
        sb_pairing_message->msg_id = counter;
        
        sb_pairing_message->X = status.X;
        sb_pairing_message->Y = status.Y;
        strcpy(sb_pairing_message->data, status.status);
        
        // Require ack
        attempt++;
        call PacketAcknowledgements.requestAck( &packet );
        
        if (call AMSend.send(address_coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
          dbg("Radio", "Radio: sanding INFO packet to node %hhu, attempt: %d\n", address_coupled_device, attempt);	
          busy = TRUE;
        }
      }
    } else {
      attempt = 0;
    }
  }
  
    event void Timer60s.fired() {
    dbg("Timer60s", "Timer60s: timer fired at time %s\n", sim_time_string());
    dbg("Info", "ALERT: MISSING");
    dbg("Info","Last known location: %hhu, Y: %hhu\n", last_status.X, last_status.Y);

    //send to serial here

  }
  }



