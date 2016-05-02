// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

//I2C EEPROM, ON Semi CAT24C32 Family
// http://www.onsemi.com/pub_link/Collateral/CAT24C32-D.PDF

//20140820 Nick Garner: Modified CAT24C Class to accommodate two byte offset

const PAGE_LEN = 32;        // page length in bytes
const WRITE_TIME = 0.005;   // max write cycle time in seconds
class CAT24C32 {
    _i2c = null;
    _addr = null;
    
    constructor(i2c, addr=0xA0) {
        _i2c = i2c;
        _addr = addr;
    }
    
    function read(len, offset) {
         // "Selective Read" by preceding the read with a "dummy write" of just the two byte offset (no data)
        _i2c.write(_addr, format("%c%c", offset&0xff, (offset>>8)&0xff));
    
        local data = _i2c.read(_addr, "", len);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x",_addr,offset));
            return -1;
        }
        return data;
    }
    
    function write(data, offset) {
        local dataIndex = 0;
        
        while(dataIndex < data.len()) {
            // chunk of data we will send per I2C write. Can be up to 1 page long.
            local chunk = format("%c%c", offset&0xff, (offset>>8)&0xff);
            
            // check if this is the first page, and if we'll hit the boundary
            local leftOnPage = PAGE_LEN - (offset % PAGE_LEN);
            // set the chunk length equal to the space left on the page
            local chunkLen = leftOnPage;
            // check if this is the last page we need to write, and adjust the chunk size if it is
            if ((data.len() - dataIndex) < leftOnPage) { chunkLen = (data.len() - dataIndex); }
            // now fill the chunk with a slice of data and write it
            for (local chunkIndex = 0; chunkIndex < chunkLen; chunkIndex++) {
                chunk += format("%c",data[dataIndex++]);  
            }
            
            _i2c.write(_addr, chunk);
            offset += chunkLen;
            // write takes a finite (and rather long) amount of time. Subsequent writes
            // before the write cycle is completed fail silently. You must wait.
            imp.sleep(WRITE_TIME);
        }
    }
}

/* RUNTIME BEGINS HERE =======================================================*/ 

//Initialize the I2C bus
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);
// Configure the EEPROM
eeprom <- CAT24C32(i2c);
// write some test data
local testStr = "Electric Imp CAT24C32!";
// write the string to the eepromm, starting at offset 0x0123
eeprom.write(testStr,0x0123);
server.log("Read back: " + eeprom.read(testStr.len(),0x0123));
