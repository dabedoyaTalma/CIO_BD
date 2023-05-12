/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_Conveyor]    Script Date: 12/05/2023 15:03:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Juan Camilo Zuluaga
-- Create date: 2019-10-16
-- Description:	Function for Businees Rules "add conveyor"
-- Change History:
--   2019-10-16 Juan Camilo Zuluaga: Function created
--   2019-12-12 Diomer Bedoya	   : En el tipo de actividad se tiene encuenta la actividad Primer conveyor
-- =============================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_Conveyor](
	@HeaderServiceId INT,
	@AirportId INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@AirplaneTypeId INT,
	@Destiny INT
	--@DateService DATE
)
RETURNS @T_Result TABLE(
		[Row] INT IDENTITY,				/*Fila*/
		StartDate DATETIME,				/*Hora Fin*/
		EndDate DATETIME,				/*Hora Fin*/
		[Time] INT,						/*Tiempo*/
		IsAdditionalService BIT,		/*Servicio Adicional*/
		AdditionalStartDate DATETIME,	/*Hora inicio Adicional*/
		AdditionalEndDate DATETIME,		/*Hora Final Adicional*/
		AdditionalTime INT,				/*Tiempo Adicional*/
		AdditionalQuantity INT,			/*Cantidad Adicional*/
		AdditionalService VARCHAR(150), /*Servicio Adicional*/
		Fraction VARCHAR(25),			/*Fraccion*/
		RemainingIncludeTime INT		/*Tiempo incluido Restante*/
	)
AS
BEGIN

	DECLARE @TM_RESTANTE FLOAT=0

	DECLARE @T_TMP_DETALLE_SRV AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO
	INSERT	@T_TMP_DETALLE_SRV
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			'CONVEYOR', --CONVEYOR
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) tiempo_total, 
			DS.cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId IN(204, 131) AND
			DS.EncabezadoServicioId = @HeaderServiceId
	
	IF (SELECT SUM(TiempoTotal) FROM @T_TMP_DETALLE_SRV) = 0 RETURN --SE TIENE ESTA LINEA PARA OPTIMIZAR EL RENDIMIENTO

	IF (	@CompanyId = 39 
		AND @BillingToCompany = 1 
		AND @AirportId = 3 
		AND @Destiny = 7
		AND @AirplaneTypeId = 60) -- RNG(MDE) INSEL AIR DESTINO ARUBA
	BEGIN
		INSERT @T_Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@T_TMP_DETALLE_SRV, 0, 60.0, NULL, NULL)
		RETURN
	END

	RETURN
END
