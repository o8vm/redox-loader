use fs::mbr::Mbr;
use alloc::Vec;
//use core_io;

pub struct Disk {
    pub current_pos: usize,
    pub id: u8
}


#[derive(Copy, Clone, Debug)]
pub enum Fs {
    FAT32,
    RedoxFS,
    Other
}

#[derive(Copy, Clone, Debug)]
pub struct PartitionTable {
    pub partitions: [Partition; 4]
}

pub struct SystemId(u8);

pub struct File<T> {
    pub file: T,
    pub args: Vec<usize>
}

#[derive(Clone, Debug, Copy)]
pub enum FsError {
    ReadError,
    WriteError,
    SeekError
}

pub trait FileOps {
    fn read(&mut self, buf: &mut [u8]) -> Result<usize, FsError>;
    fn write(&mut self, buf: &mut [u8]) -> Result<usize, FsError>;
    fn seek(&mut self, pos: SeekFrom) -> Result<u64, FsError>;
    fn size(&mut self) -> usize; 
}

pub enum SeekFrom {
    Start(u64),
    End(i64),
    Current(i64),
}



impl SystemId {
    fn get_fs(&self) -> Fs {
        match self.0 {
            0x0c => Fs::FAT32,
            0x7f => Fs::RedoxFS,
            _ => { println!("Unsupported partition"); Fs::Other }
        }
    }
}

#[derive(Copy, Clone, Debug)]
pub struct Partition {
    // The starting sector number
    pub start_sector: u32,
    // Length of the partition in sectors
    pub length: usize,
    // Seek position wrt start of partition
    pub relative_pos: usize,
    // Type of the filesystem
    pub fs: Fs,
    // Partition bootable flag
    pub is_boot: bool,
}

impl Partition {

    pub fn default() -> Partition {
        Partition {
            start_sector: 0,
            length: 0,
            relative_pos: 0,
            fs: Fs::Other,
            is_boot: false
        }
    }

    
}

impl PartitionTable {

    pub fn new(mbr: &Mbr) -> PartitionTable {
        let mut table = PartitionTable { partitions: [Partition::default(); 4] };
        for (idx, partition) in mbr.partition_table.iter().enumerate() {
            let systemid = SystemId(partition.system_id());
            table.partitions[idx] = Partition { 
                start_sector: partition.starting_lba(), 
                length: partition.partition_length() as usize, 
                relative_pos: 0, 
                fs: systemid.get_fs(), 
                is_boot: partition.is_bootable()
            };
        
        }

        table
    }
    
    pub fn get_bootable(&self) -> Option<(Partition, usize)> {
        for (idx, partition) in self.partitions.iter().enumerate() {
            if partition.is_boot {
                return Some((*partition, idx))
            }
        }
        None
    }

}
