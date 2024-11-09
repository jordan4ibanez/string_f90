program example
  use, intrinsic :: iso_c_binding
  use :: string_f90
  implicit none

  character(len = 1, kind = c_char), dimension(:), pointer :: char_array
  character(len = :, kind = c_char), pointer :: str

  allocate(char_array(10))

  char_array = ["h","i", achar(0), achar(0), achar(0), achar(0), achar(0), achar(0), achar(0), achar(0)]

  str => character_array_to_string_pointer(char_array)

  print*,str
  print*,len(str)



end program example
