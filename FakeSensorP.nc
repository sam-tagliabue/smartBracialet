#include <stdio.h>
#include "smartBracelet.h"
generic module FakeSensorP() {

	provides interface Read<sensor_status>;
	uses interface Random;

}

implementation 
{

	task void readDone();

	//***************** Read interface ********************//
	command error_t Read.read(){
		post readDone();
		return SUCCESS;
	}

	//******************** Read Done **********************//
	task void readDone() {
	  
	  sensor_status status;

	  int random_number = (call Random.rand16() % 10);
		
		if (random_number <= 2){
		status.status=1; // standing
		} else if (random_number <= 5){
		status.status=2; //walking
		} else if (random_number <= 8){
		status.status=3; // running
		} else {
		status.status=4; // falling
		}
		
		signal Read.readDone( SUCCESS, status);
	  status.X = call Random.rand16();
	  status.Y = call Random.rand16();

	}
}  
