BEGIN{
  s=1;
  printf "[ ";
}
{
  if( s == 1 )
  {
     { printf "[ \"%s\", \"%i\" ]", $1, $2 };
     s=0;
  }
  else
  {
     { printf " , [ \"%s\", \"%i\" ]", $1, $2 };
  }
}
END{
  printf " ]";
}

